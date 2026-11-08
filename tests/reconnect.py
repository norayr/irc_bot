"""Local IRC server regressions; uses only Python's standard library."""

import contextlib
import pathlib
import signal
import socket
import subprocess
import sys
import tempfile
import time


class Peer:
    def __init__(self, connection):
        self.connection = connection
        self.buffer = b""

    def send(self, text):
        self.connection.sendall(text.encode())

    def line(self, timeout=3):
        deadline = time.monotonic() + timeout
        while b"\n" not in self.buffer:
            self.connection.settimeout(max(0.001, deadline - time.monotonic()))
            data = self.connection.recv(65536)
            assert data, f"unexpected EOF; pending {self.buffer!r}"
            self.buffer += data
        line, self.buffer = self.buffer.split(b"\n", 1)
        assert line.endswith(b"\r"), f"missing CRLF: {line!r}"
        assert len(line) + 1 <= 512, f"outgoing IRC line too long: {len(line) + 1}"
        return line[:-1].decode()

    def expect(self, expected, timeout=3):
        actual = self.line(timeout)
        assert actual == expected, (actual, expected)

    def closed(self, timeout=3):
        self.connection.settimeout(timeout)
        assert self.connection.recv(65536) == b"", "expected disconnect"

    def close(self):
        self.connection.close()


def listener():
    server = socket.socket()
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", 0))
    return server


def accept(server, timeout=3):
    server.settimeout(timeout)
    connection, _ = server.accept()
    return Peer(connection)


@contextlib.contextmanager
def running(command, directory):
    with tempfile.TemporaryFile() as output:
        process = subprocess.Popen(command, cwd=directory, stdout=output, stderr=output)
        failed = False
        try:
            yield process
        except BaseException:
            failed = True
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=3)
            output.seek(0)
            print(output.read().decode(errors="replace"), file=sys.stderr)
            raise
        finally:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            if not failed:
                assert process.returncode == 0, f"process exited with {process.returncode}"


def probe_registration(peer):
    peer.expect("PASS secret-password")
    peer.expect("NICK probe")
    peer.expect("USER testuser 0 * :owner")


def welcome(peer, nick="probe", channels=("#one", "#two")):
    peer.send(f":server 001 {nick} :Welcome\r\n")
    peer.expect(f"MODE {nick} +i")
    for channel in channels:
        peer.expect(f"JOIN {channel}")


def protocol_tests(probe, directory):
    with listener() as server:
        port = server.getsockname()[1]
        # Refuse the first attempts, then allow the same process to recover.
        with running([str(probe), str(port)], directory):
            time.sleep(0.45)
            server.listen()
            peer = accept(server)
            probe_registration(peer)
            peer.send(":server 00")
            time.sleep(0.15)
            peer.send("1 probe :Welcome\r")
            time.sleep(0.15)
            peer.send("\n:bob!ident@host PRIVMSG #one :first\r\nPING :one\r\n"
                      ":bob!~ident@host PRIVMSG probe :hello\r\nPING :two\r\n")
            peer.expect("MODE probe +i")
            peer.expect("JOIN #one")
            peer.expect("JOIN #two")
            peer.expect("PRIVMSG #events :#one|PRIVMSG|bob|ident|host|first")
            peer.expect("PONG :one")
            peer.expect("PRIVMSG #events :private|PRIVMSG|bob|ident|host|hello")
            peer.expect("PONG :two")
            # A prefixed PING after other traffic must also be answered.
            peer.send("@time=now :bob!ident@host JOIN :#one\r\n:server PING :prefixed\r\n"
                      ":bob!ident@host PRIVMSG #one :probe: addressed\r\n"
                      ":bob!ident@host PRIVMSG #one :hello probe, there\r\n")
            peer.expect("PRIVMSG #events :#one|JOIN|bob|ident|host|")
            peer.expect("PONG :prefixed")
            peer.expect("PRIVMSG #events :mention|PRIVMSG|bob|ident|host|addressed")
            peer.expect("PRIVMSG #events :mention|PRIVMSG|bob|ident|host|hello probe, there")
            peer.send(":bob!ident@host PRIVMSG PROBE :mixed case\r\n"
                      ":bob!ident@host PRIVMSG #ONE :\x01ACTION waves\x01\r\n"
                      ":bob!ident@host PART #outside\r\n")
            peer.expect("PRIVMSG #events :private|PRIVMSG|bob|ident|host|mixed case")
            peer.expect("PRIVMSG #events :#ONE|PRIVMSG|bob|ident|host|\x01ACTION waves\x01")
            peer.expect("PRIVMSG #events :#outside|PART|bob|ident|host|")
            peer.send(":bob!ident@host PRIVMSG #one :" + "a" * 700 + "\r\n")
            long_reply = "PRIVMSG #events :#one|PRIVMSG|bob|ident|host|" + "a" * 700
            peer.expect(long_reply[:510])
            peer.send(":bob!ident@host PRIVMSG #one :one\rtwo\r\n")
            peer.expect("PRIVMSG #events :#one|PRIVMSG|bob|ident|host|one two")
            # Buffered fragments from an old socket must not survive reconnect.
            peer.send(":bob!ident@host PRIVMSG #one :abandoned")
            time.sleep(0.15)
            peer.close()
            peer = accept(server)
            probe_registration(peer)
            welcome(peer)
            peer.send("PING :after-eof\r\n")
            peer.expect("PONG :after-eof")
            # ERROR need not contain the old hardcoded 'Closing Link' text.
            peer.send("ERROR :Server restarting\r\n")
            peer.closed()
            peer.close()
            peer = accept(server)
            probe_registration(peer)
            # An accepted TCP connection without 001 must time out.
            peer.closed()
            peer.close()
            peer = accept(server)
            probe_registration(peer)
            welcome(peer)
            peer.expect("PING :voc-keepalive")
            # Unrelated PONGs must not hide a lost keepalive response.
            peer.send(":server PONG server :wrong-token\r\n")
            peer.closed()
            peer.close()
            peer = accept(server)
            probe_registration(peer)
            welcome(peer)
            for _ in range(3):
                peer.expect("PING :voc-keepalive")
                peer.send(":server PONG server :voc-keepalive\r\n")
            peer.send("PING :still-here\r\n")
            peer.expect("PONG :still-here")
            # Reject oversized lines without treating the tail as a new command.
            peer.send("x" * 11712)
            peer.closed()
            peer.close()
            peer = accept(server)
            probe_registration(peer)
            welcome(peer)
        peer.expect("QUIT :interrupt")
        peer.close()

    # Existing clients that explicitly Connect/Auth must keep that socket.
    with listener() as server:
        server.listen()
        with running([str(probe), str(server.getsockname()[1]), "legacy"], directory):
            peer = accept(server)
            probe_registration(peer)
            welcome(peer)
            peer.send("PING :single-connection\r\n")
            peer.expect("PONG :single-connection")
            peer.send(":PROBE!ident@host NICK :changed\r\n"
                      ":bob!ident@host PRIVMSG CHANGED :new nick\r\n")
            peer.expect("PRIVMSG #events :private|PRIVMSG|bob|ident|host|new nick")
            server.settimeout(0.15)
            try:
                extra, _ = server.accept()
            except socket.timeout:
                pass
            else:
                extra.close()
                raise AssertionError("opened a duplicate connection")
        peer.expect("QUIT :interrupt")
        peer.close()
    log = (pathlib.Path(directory) / "#one").read_text()
    assert "***bob waves" in log
    assert "#outside" not in log
    print("PASS: IRC framing, PING/PONG, registration timeout, idle timeout, EOF/ERROR reconnects")


def bot_tests(bot, directory):
    log = pathlib.Path(directory) / "#room"
    # An oversized old line and an unterminated final line must load safely.
    log.write_text("x" * 13000 + "\n2026-1-1 (0:0:0) old: preloaded")
    with listener() as server:
        server.listen()
        command = [str(bot), "-h", "127.0.0.1", "-p", str(server.getsockname()[1]),
                   "-o", "owner", "-u", "testuser", "-n", "bot", "-r", "#room", "-l", "3"]
        with running(command, directory):
            peer = accept(server)
            # Empty password must not produce a PASS command.
            peer.expect("NICK bot")
            peer.expect("USER testuser 0 * :owner")
            welcome(peer, "bot", ("#room",))
            peer.send(":bob!ident@host PRIVMSG bot :last 1\r\nPING :loaded\r\n")
            peer.expect("PONG :loaded")
            peer.expect("PRIVMSG bob :old: preloaded")
            peer.send(":alice!ident@host PRIVMSG #room :first\r\n"
                      ":alice!ident@host PRIVMSG #room :second\r\n"
                      ":alice!ident@host PRIVMSG #room :third\r\n"
                      ":bob!ident@host PRIVMSG bot :last 3\r\nPING :during-history\r\n")
            peer.expect("PONG :during-history", timeout=1)
            peer.expect("PRIVMSG bob :alice: first")
            started = time.monotonic()
            peer.send("PING :between-replies\r\n")
            peer.expect("PONG :between-replies", timeout=1)
            peer.expect("PRIVMSG bob :alice: second")
            assert time.monotonic() - started >= 1.7, "history replies are flooding"
            peer.expect("PRIVMSG bob :alice: third")
            peer.send(":bob!ident@host PRIVMSG bot :  SeArCh 1 second\r\n")
            peer.expect("PRIVMSG bob :Found 1 matches. Showing last 1:")
            peer.expect("PRIVMSG bob :alice: second")
            # NOTICEs are never interpreted as bot commands.
            peer.send(":server NOTICE bot :help\r\nPING :notice\r\n")
            peer.expect("PONG :notice")
            peer.send(":bob!ident@host PRIVMSG bot :last 0\r\n")
            peer.expect("PRIVMSG bob :Use 'last n' with a positive message count.")
            peer.close()
            # Exercise the production reconnect delay and preserve memory history.
            peer = accept(server, timeout=26)
            peer.expect("NICK bot")
            peer.expect("USER testuser 0 * :owner")
            welcome(peer, "bot", ("#room",))
            peer.send(":bob!ident@host PRIVMSG bot :last 1\r\nPING :reconnected\r\n")
            peer.expect("PONG :reconnected")
            peer.expect("PRIVMSG bob :alice: third")
        peer.expect("QUIT :interrupt")
        peer.close()
    assert "alice: third" in log.read_text()

    # Empty history used to enter a REPEAT loop that could never finish.
    log.write_text("")
    with listener() as server:
        server.listen()
        command[command.index("-p") + 1] = str(server.getsockname()[1])
        with running(command, directory):
            peer = accept(server)
            peer.expect("NICK bot")
            peer.expect("USER testuser 0 * :owner")
            welcome(peer, "bot", ("#room",))
            peer.send(":bob!ident@host PRIVMSG bot :last 1\r\nPING :empty\r\n")
            peer.expect("PONG :empty")
            peer.expect("PRIVMSG bob :I do not remember any messages yet.")
        peer.expect("QUIT :interrupt")
        peer.close()
    print("PASS: bot history, search, reply pacing, PING during replies, reconnect and log loading")


def main():
    bot, irc_source, compiler = sys.argv[1:]
    with tempfile.TemporaryDirectory(prefix="irc-tests-") as directory:
        source = pathlib.Path(__file__).with_name("IRCProbe.Mod").resolve()
        subprocess.run([compiler, "-s", irc_source], cwd=directory, check=True)
        subprocess.run([compiler, "-m", str(source)], cwd=directory, check=True)
        protocol_tests(pathlib.Path(directory) / "IRCProbe", directory)
        bot_tests(pathlib.Path(bot), directory)


if __name__ == "__main__":
    main()
