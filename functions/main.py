import base64
import json
import logging
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import NoReturn

import firebase_admin
from firebase_admin import firestore, storage
from firebase_functions import https_fn, options
from firebase_functions.params import SecretParam

GEMINI_API_KEY = SecretParam("GEMINI_API_KEY")
_MODEL = "google/gemini-2.5-flash"
_USER_MESSAGE = "تعذر إتمام الطلب"
_MAX_BYTES = 7 * 1024 * 1024
_LIMIT = 8

if not firebase_admin._apps:
    firebase_admin.initialize_app()


def _fail(code: https_fn.FunctionsErrorCode) -> NoReturn:
    raise https_fn.HttpsError(code=code, message=_USER_MESSAGE)


def _image_kind(data: bytes) -> str | None:
    if len(data) < 12 or len(data) > _MAX_BYTES:
        return None
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return "image/webp"
    return None


def _allowed_path(uid: str, path: str) -> bool:
    if not uid or not path or ".." in path or "\\" in path or path.startswith("/"):
        return False
    prefix = f"users/{uid}/frames/"
    if not path.startswith(prefix) or not path.endswith(".jpg"):
        return False
    name = path[len(prefix):]
    if "/" in name or not name[:-4]:
        return False
    return name[:-4].replace("_", "").replace("-", "").isalnum()


def _allow_call(uid: str) -> bool:
    db = firestore.client()
    ref = db.collection("rate_limits").document(uid)
    now = datetime.now(timezone.utc)

    @firestore.transactional
    def bump(transaction):
        snap = ref.get(transaction=transaction)
        data = snap.to_dict() or {}
        start = data.get("window_start")
        count = int(data.get("count") or 0)
        if start is not None and start.tzinfo is None:
            start = start.replace(tzinfo=timezone.utc)
        if start is None or (now - start).total_seconds() >= 60:
            transaction.set(ref, {"window_start": now, "count": 1})
            return True
        if count >= _LIMIT:
            return False
        transaction.update(ref, {"count": count + 1})
        return True

    return bool(bump(db.transaction()))


def _prompt(mode: str) -> str:
    if mode == "read":
        return "استخرج النص الظاهر في الصورة فقط. إذا كان النص بلغة أخرى فاقرأه كما هو. إذا لم يوجد نص فقل: لا يوجد نص واضح في الصورة. لا تضف وصفاً للمشهد ولا تخترع كلمات غير ظاهرة."
    return "أنت مساعد لشخص كفيف. صف المشهد بالعربية الفصحى البسيطة في فقرة قصيرة، مع ذكر العقبات القريبة والاتجاه إذا كان واضحاً. لا تخترع أشياء غير ظاهرة. إذا كانت الصورة غير واضحة فقل ذلك."


@https_fn.on_call(
    secrets=[GEMINI_API_KEY],
    region="us-central1",
    memory=options.MemoryOption.MB_512,
    timeout_sec=60,
    max_instances=10,
    enforce_app_check=True,
)
def analyze_scene(req: https_fn.CallableRequest) -> dict:
    uid = req.auth.uid if req.auth is not None else None
    if not uid:
        _fail(https_fn.FunctionsErrorCode.UNAUTHENTICATED)
    data = req.data if isinstance(req.data, dict) else {}
    path = data.get("path")
    mode = data.get("mode")
    if not isinstance(path, str) or not isinstance(mode, str) or mode not in ("describe", "read"):
        _fail(https_fn.FunctionsErrorCode.INVALID_ARGUMENT)
    if not _allowed_path(uid, path):
        _fail(https_fn.FunctionsErrorCode.INVALID_ARGUMENT)
    try:
        if not _allow_call(uid):
            _fail(https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED)
        blob = storage.bucket().blob(path)
        blob.reload()
        size = blob.size or 0
        if size <= 0 or size > _MAX_BYTES:
            _fail(https_fn.FunctionsErrorCode.INVALID_ARGUMENT)
        raw = blob.download_as_bytes()
        mime = _image_kind(raw)
        if mime is None:
            _fail(https_fn.FunctionsErrorCode.INVALID_ARGUMENT)
        key = GEMINI_API_KEY.value.strip()
        if not key:
            logging.error("analyze_scene missing_key")
            _fail(https_fn.FunctionsErrorCode.INTERNAL)
        text = _gemini_text(key, mime, raw, _prompt(mode))
        if not text:
            logging.error("analyze_scene empty_response")
            _fail(https_fn.FunctionsErrorCode.INTERNAL)
        return {"text": text}
    except https_fn.HttpsError:
        raise
    except Exception:
        logging.exception("analyze_scene failed")
        _fail(https_fn.FunctionsErrorCode.INTERNAL)


def _gemini_text(key: str, mime: str, raw: bytes, prompt: str) -> str:
    body = {
        "model": _MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": "data:" + mime + ";base64," + base64.b64encode(raw).decode("ascii")},
                    },
                ],
            }
        ],
    }
    request = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        logging.error("analyze_scene upstream_status %s", exc.code)
        raise
    choices = payload.get("choices") or []
    if not choices:
        return ""
    content = (choices[0].get("message") or {}).get("content") or ""
    if isinstance(content, list):
        parts = [item.get("text") or "" for item in content if isinstance(item, dict)]
        return "".join(parts).strip()
    return str(content).strip()


def _check() -> None:
    assert _allowed_path("abc", "users/abc/frames/12.jpg")
    assert not _allowed_path("abc", "users/other/frames/12.jpg")
    assert not _allowed_path("abc", "users/abc/frames/../../x.jpg")
    assert _image_kind(b"\xff\xd8\xff" + b"0" * 9) == "image/jpeg"
    assert _image_kind(b"\x89PNG\r\n\x1a\n" + b"0" * 4) == "image/png"
    assert _image_kind(b"not-an-image!!") is None


if __name__ == "__main__":
    _check()
