import pytest

from app.core.security import hash_password, verify_password


def test_hash_password_success():
    """Verify that hash_password generates a valid bcrypt hash."""
    plain = "SuperSecretPassword123!"
    hashed = hash_password(plain)

    assert isinstance(hashed, str)
    assert hashed.startswith("$2b$")
    assert len(hashed) == 60
    assert hashed != plain


def test_hash_password_generates_unique_salts():
    """Verify that multiple hashes of the same password produce different hashes due to salting."""
    plain = "IdenticalPassword456!"
    hash1 = hash_password(plain)
    hash2 = hash_password(plain)

    assert hash1 != hash2
    assert verify_password(plain, hash1) is True
    assert verify_password(plain, hash2) is True


def test_hash_password_empty_raises_value_error():
    """Verify that attempting to hash an empty string raises ValueError."""
    with pytest.raises(ValueError, match="Password cannot be empty"):
        hash_password("")


def test_verify_password_correct():
    """Verify that verify_password returns True for matching password."""
    plain = "CorrectPassword#2026"
    hashed = hash_password(plain)

    assert verify_password(plain, hashed) is True


def test_verify_password_incorrect():
    """Verify that verify_password returns False for wrong password."""
    plain = "MyPassword"
    wrong = "WrongPassword"
    hashed = hash_password(plain)

    assert verify_password(wrong, hashed) is False


def test_verify_password_empty_inputs():
    """Verify that verify_password returns False for empty plain or hash strings."""
    hashed = hash_password("ValidPassword")

    assert verify_password("", hashed) is False
    assert verify_password("ValidPassword", "") is False
    assert verify_password("", "") is False


def test_verify_password_malformed_hash():
    """Verify that verify_password safely returns False on invalid/malformed hashes."""
    assert verify_password("password", "invalid_not_a_bcrypt_hash") is False
    assert verify_password("password", "$2b$12$short") is False
    assert verify_password("password", "$invalid$prefix$hash") is False


def test_password_unicode_and_special_characters():
    """Verify that unicode characters and symbols are handled properly."""
    passwords = [
        "MậtKhẩuViệtNam2026!@#",
        "Pässwørd_with_ümlaut",
        "SecurePassword🔐🚀🔥",
        "   leading_and_trailing_spaces   ",
    ]

    for pwd in passwords:
        hashed = hash_password(pwd)
        assert verify_password(pwd, hashed) is True
        assert verify_password(pwd + "_wrong", hashed) is False
