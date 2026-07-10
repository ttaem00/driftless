"""Validate a classroom recording before processing."""


def accept_recording(path: str) -> dict[str, str]:
    if not path.lower().endswith((".mp3", ".mp4", ".wav")):
        raise ValueError("unsupported classroom media format")
    return {"media_path": path, "status": "accepted"}
