"""Render a lesson record as a static HTML fragment."""

from html import escape


def render_lesson(lesson: dict[str, object]) -> str:
    title = str(lesson.get("title", "Untitled lesson"))
    return f"<article><h1>{escape(title)}</h1></article>"
