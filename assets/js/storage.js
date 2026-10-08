// localStorage can be unavailable (private windows, blocked site data), so
// settings kept there fall back to their defaults.
export function read(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

// Stores `value` under `key`, or forgets the key for `null`.
export function write(key, value) {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, value);
  } catch {
    // The setting still applies, it just isn't remembered.
  }
}
