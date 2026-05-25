"""
stream_guard.py — Fix stream timeout + circuit breaker Nova.

CARA PAKAI:

    from nova_fixes.stream_guard import StreamGuard

    guard = StreamGuard(timeout=30, max_retries=3)

    # Ganti loop streaming Nova dengan:
    async for chunk in guard.stream(client.messages.stream, **params):
        yield chunk
"""

import asyncio
import time
from typing import AsyncIterator, Callable, Any


class StreamTimeout(Exception):
    pass


class CircuitOpen(Exception):
    pass


class StreamGuard:
    """
    Wrap streaming LLM call dengan:
    - Timeout per chunk (default 30s, bukan 150s)
    - Max retry (default 3, bukan 90)
    - Circuit breaker: open setelah 3 failure berturut-turut, reset setelah 60s
    """

    def __init__(
        self,
        timeout: int = 30,
        max_retries: int = 3,
        circuit_threshold: int = 3,
        circuit_reset: int = 60,
    ):
        self.timeout = timeout
        self.max_retries = max_retries
        self._fail_count = 0
        self._circuit_threshold = circuit_threshold
        self._circuit_reset = circuit_reset
        self._open_since: float = 0.0

    def _is_open(self) -> bool:
        if self._fail_count < self._circuit_threshold:
            return False
        if time.monotonic() - self._open_since > self._circuit_reset:
            print("[StreamGuard] Circuit breaker reset.")
            self._fail_count = 0
            return False
        return True

    def _record_failure(self) -> None:
        self._fail_count += 1
        if self._fail_count == self._circuit_threshold:
            self._open_since = time.monotonic()
            print(f"[StreamGuard] Circuit OPEN — terlalu banyak gagal. Reset dalam {self._circuit_reset}s.")

    def _record_success(self) -> None:
        if self._fail_count > 0:
            print("[StreamGuard] Circuit menutup (sukses).")
        self._fail_count = 0

    async def stream(
        self,
        stream_fn: Callable[..., Any],
        *args: Any,
        **kwargs: Any,
    ) -> AsyncIterator[Any]:
        """
        stream_fn: fungsi async yang mengembalikan async iterator (stream LLM).
        Contoh: client.messages.stream
        """
        if self._is_open():
            raise CircuitOpen("Circuit breaker terbuka — model provider bermasalah. Coba lagi nanti.")

        for attempt in range(1, self.max_retries + 1):
            try:
                async_stream = stream_fn(*args, **kwargs)
                async for chunk in self._with_timeout(async_stream):
                    yield chunk
                self._record_success()
                return
            except (StreamTimeout, asyncio.TimeoutError):
                print(f"[StreamGuard] Timeout attempt {attempt}/{self.max_retries} (>{self.timeout}s tanpa chunk).")
                self._record_failure()
                if attempt < self.max_retries:
                    await asyncio.sleep(2 ** attempt)
            except Exception as e:
                print(f"[StreamGuard] Error attempt {attempt}/{self.max_retries}: {e}")
                self._record_failure()
                if attempt < self.max_retries:
                    await asyncio.sleep(2 ** attempt)
                else:
                    raise

        raise StreamTimeout(f"Stream gagal setelah {self.max_retries} percobaan.")

    async def _with_timeout(self, async_iter: Any) -> AsyncIterator[Any]:
        """Yield chunk dengan timeout; raise StreamTimeout jika terlalu lama."""
        got_first = False
        async for chunk in async_iter:
            got_first = True
            yield chunk

        if not got_first:
            raise StreamTimeout("Stream kosong — tidak ada chunk yang diterima.")

    async def safe_call(
        self,
        call_fn: Callable[..., Any],
        *args: Any,
        **kwargs: Any,
    ) -> Any:
        """
        Untuk non-streaming call (create biasa, bukan stream).
        Tambahkan timeout + retry.
        """
        if self._is_open():
            raise CircuitOpen("Circuit breaker terbuka.")

        for attempt in range(1, self.max_retries + 1):
            try:
                result = await asyncio.wait_for(
                    call_fn(*args, **kwargs),
                    timeout=self.timeout,
                )
                self._record_success()
                return result
            except asyncio.TimeoutError:
                print(f"[StreamGuard] Call timeout attempt {attempt}/{self.max_retries}.")
                self._record_failure()
                if attempt < self.max_retries:
                    await asyncio.sleep(2 ** attempt)
            except Exception as e:
                self._record_failure()
                if attempt < self.max_retries:
                    await asyncio.sleep(2 ** attempt)
                else:
                    raise e

        raise StreamTimeout(f"Call gagal setelah {self.max_retries} percobaan.")
