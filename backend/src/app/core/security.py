import bcrypt


def hash_password(password: str) -> str:
    """
    Hash a plain text password using bcrypt with a randomly generated salt.

    :param password: The plain text password to hash.
    :return: The bcrypt hashed password string.
    :raises ValueError: If the password is empty.
    """
    if not password:
        raise ValueError("Password cannot be empty.")

    password_bytes = password.encode("utf-8")
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a plain text password against a stored bcrypt hashed password.

    :param plain_password: The plain text password candidate.
    :param hashed_password: The bcrypt hash stored in the database.
    :return: True if the password matches the hash, False otherwise.
    """
    if not plain_password or not hashed_password:
        return False

    try:
        plain_bytes = plain_password.encode("utf-8")
        hash_bytes = hashed_password.encode("utf-8")
        return bcrypt.checkpw(plain_bytes, hash_bytes)
    except ValueError, TypeError:
        return False
