import re


_SMALL_TALK_PATTERNS = (
    re.compile(r"^(?:h(?:i+|ello+|ey+)|howdy)(?: there| cognexa)?$"),
    re.compile(r"^good (?:morning|afternoon|evening)(?: there)?$"),
    re.compile(r"^(?:how are you(?: doing)?|how is it going|how's it going|what is up|what's up)$"),
    re.compile(r"^(?:thanks|thank you|thx)(?: so much| very much)?$"),
    re.compile(r"^(?:bye|goodbye|see you|talk to you later)$"),
    re.compile(r"^(?:ok|okay|got it|great|nice|cool)$"),
    re.compile(r"^(?:who are you|what are you|what can you do)$"),
)


def small_talk_intent(query: str) -> str | None:
    """Return the recognized conversational intent for standalone small talk."""
    normalized = re.sub(r"[!?.,]+", " ", query.lower())
    normalized = " ".join(normalized.split())

    for pattern in _SMALL_TALK_PATTERNS:
        if pattern.fullmatch(normalized):
            return normalized

    return None


def small_talk_reply(intent: str) -> str:
    if intent.startswith(("hi", "he", "howdy", "good ")):
        return "Hi! I'm Cognexa. Ask me anything about the documents in this workspace."
    if intent.startswith(("thank", "thanks", "thx")):
        return "You're welcome! What else would you like to know from your workspace documents?"
    if intent in {"bye", "goodbye", "see you", "talk to you later"}:
        return "Goodbye! Come back any time you need help with your workspace documents."
    if intent in {"who are you", "what are you", "what can you do"}:
        return "I'm Cognexa, an assistant that finds and explains information in your workspace documents, with source references."
    if intent in {"how are you", "how are you doing", "how is it going", "how's it going", "what is up", "what's up"}:
        return "I'm ready to help. What would you like to know from your workspace documents?"
    return "Got it. What would you like to know from your workspace documents?"
