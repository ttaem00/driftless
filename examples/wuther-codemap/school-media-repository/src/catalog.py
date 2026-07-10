"""Create a searchable lesson record from a transcript."""


def index_lesson(transcript: list[dict[str, object]]) -> dict[str, object]:
    if not transcript:
        raise ValueError("transcript must contain at least one segment")
    return {"title": "Synthetic lesson", "segments": transcript}
