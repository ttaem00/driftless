"""Turn accepted media into timestamped lesson text."""


def build_transcript(media: dict[str, str]) -> list[dict[str, object]]:
    if media.get("status") != "accepted":
        raise ValueError("media must pass intake")
    return [{"second": 0, "text": "Synthetic lesson introduction."}]
