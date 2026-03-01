#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# Mock RTMP Server for swift-rtmp-kit manual testing.
#
# Usage:
#   python3 mock-rtmp-server.py                          # Normal mode (port 1935)
#   python3 mock-rtmp-server.py --port 19350             # Custom port
#   python3 mock-rtmp-server.py --fail auth              # Reject RTMP connect
#   python3 mock-rtmp-server.py --fail publish           # Reject publish
#   python3 mock-rtmp-server.py --fail handshake         # Corrupted S2
#   python3 mock-rtmp-server.py --enhanced               # Enhanced RTMP support
#   python3 mock-rtmp-server.py --verbose                # Hex dumps + chunk tracing

import argparse
import socket
import struct
import threading
import time
import sys
import os
import signal

# ─── Constants ────────────────────────────────────────────────────────

RTMP_VERSION = 3
HANDSHAKE_SIZE = 1536
DEFAULT_CHUNK_SIZE = 128
DEFAULT_WINDOW_ACK_SIZE = 2_500_000
DEFAULT_PEER_BANDWIDTH = 2_500_000

MSG_SET_CHUNK_SIZE = 1
MSG_ABORT = 2
MSG_ACK = 3
MSG_USER_CONTROL = 4
MSG_WINDOW_ACK_SIZE = 5
MSG_SET_PEER_BANDWIDTH = 6
MSG_AUDIO = 8
MSG_VIDEO = 9
MSG_AMF0_DATA = 18
MSG_AMF0_COMMAND = 20

AMF0_NUMBER = 0x00
AMF0_BOOLEAN = 0x01
AMF0_STRING = 0x02
AMF0_OBJECT = 0x03
AMF0_NULL = 0x05
AMF0_ECMA_ARRAY = 0x08
AMF0_OBJECT_END = 0x09


# ─── Colors ───────────────────────────────────────────────────────────

class Color:
    RESET = "\033[0m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"
    GRAY = "\033[90m"
    BOLD = "\033[1m"

if not (hasattr(sys.stdout, 'isatty') and sys.stdout.isatty()):
    for attr in dir(Color):
        if not attr.startswith('_'):
            setattr(Color, attr, '')


# ─── AMF0 Encoder ────────────────────────────────────────────────────

def amf0_encode_number(value):
    return struct.pack('>Bd', AMF0_NUMBER, float(value))

def amf0_encode_boolean(value):
    return struct.pack('>BB', AMF0_BOOLEAN, 1 if value else 0)

def amf0_encode_string(value):
    encoded = value.encode('utf-8')
    return struct.pack('>BH', AMF0_STRING, len(encoded)) + encoded

def amf0_encode_null():
    return struct.pack('>B', AMF0_NULL)

def amf0_encode_object(obj):
    data = struct.pack('>B', AMF0_OBJECT)
    for key, value in obj.items():
        key_encoded = key.encode('utf-8')
        data += struct.pack('>H', len(key_encoded)) + key_encoded
        data += amf0_encode_value(value)
    data += struct.pack('>HB', 0, AMF0_OBJECT_END)
    return data

def amf0_encode_value(value):
    if value is None:
        return amf0_encode_null()
    elif isinstance(value, bool):
        return amf0_encode_boolean(value)
    elif isinstance(value, (int, float)):
        return amf0_encode_number(value)
    elif isinstance(value, str):
        return amf0_encode_string(value)
    elif isinstance(value, dict):
        return amf0_encode_object(value)
    else:
        return amf0_encode_null()


# ─── AMF0 Decoder ────────────────────────────────────────────────────

class AMF0Decoder:
    def __init__(self, data):
        self.data = data
        self.pos = 0

    def remaining(self):
        return len(self.data) - self.pos

    def read_bytes(self, n):
        if self.pos + n > len(self.data):
            raise ValueError(f"AMF0 underflow: need {n}, have {self.remaining()}")
        result = self.data[self.pos:self.pos + n]
        self.pos += n
        return result

    def decode_value(self):
        if self.remaining() < 1:
            return None
        marker = self.data[self.pos]
        self.pos += 1
        if marker == AMF0_NUMBER:
            return struct.unpack('>d', self.read_bytes(8))[0]
        elif marker == AMF0_BOOLEAN:
            return self.read_bytes(1)[0] != 0
        elif marker == AMF0_STRING:
            length = struct.unpack('>H', self.read_bytes(2))[0]
            return self.read_bytes(length).decode('utf-8', errors='replace')
        elif marker == AMF0_OBJECT:
            return self._decode_object_properties()
        elif marker == AMF0_NULL:
            return None
        elif marker == AMF0_ECMA_ARRAY:
            _count = struct.unpack('>I', self.read_bytes(4))[0]
            return self._decode_object_properties()
        else:
            return None

    def _decode_object_properties(self):
        obj = {}
        while self.remaining() >= 3:
            key_len = struct.unpack('>H', self.read_bytes(2))[0]
            if key_len == 0:
                if self.remaining() >= 1:
                    marker = self.data[self.pos]
                    self.pos += 1
                    if marker == AMF0_OBJECT_END:
                        break
                break
            key = self.read_bytes(key_len).decode('utf-8', errors='replace')
            value = self.decode_value()
            obj[key] = value
        return obj

    def decode_all(self):
        values = []
        while self.remaining() > 0:
            try:
                value = self.decode_value()
                values.append(value)
            except (ValueError, struct.error):
                break
        return values


# ─── RTMP Chunk Reader ───────────────────────────────────────────────

class ChunkReader:
    def __init__(self, sock, verbose=False):
        self.sock = sock
        self.chunk_size = DEFAULT_CHUNK_SIZE
        self.prev_headers = {}
        self.assembly = {}
        self.verbose = verbose

    def recv_exact(self, n):
        data = b''
        while len(data) < n:
            chunk = self.sock.recv(n - len(data))
            if not chunk:
                raise ConnectionError("Connection closed")
            data += chunk
        return data

    def _trace(self, msg):
        if self.verbose:
            print(f"  {Color.GRAY}[CHUNK] {msg}{Color.RESET}")

    def read_message(self):
        while True:
            # Basic header
            b0 = self.recv_exact(1)[0]
            fmt = (b0 >> 6) & 0x03
            csid = b0 & 0x3F

            if csid == 0:
                csid = self.recv_exact(1)[0] + 64
            elif csid == 1:
                b = self.recv_exact(2)
                csid = b[1] * 256 + b[0] + 64

            prev = self.prev_headers.get(csid, {})
            timestamp = prev.get('timestamp', 0)
            msg_length = prev.get('msg_length', 0)
            msg_type = prev.get('msg_type', 0)
            msg_stream_id = prev.get('msg_stream_id', 0)

            if fmt == 0:
                hdr = self.recv_exact(11)
                timestamp = (hdr[0] << 16) | (hdr[1] << 8) | hdr[2]
                msg_length = (hdr[3] << 16) | (hdr[4] << 8) | hdr[5]
                msg_type = hdr[6]
                msg_stream_id = struct.unpack('<I', hdr[7:11])[0]
                if timestamp == 0xFFFFFF:
                    timestamp = struct.unpack('>I', self.recv_exact(4))[0]
            elif fmt == 1:
                hdr = self.recv_exact(7)
                td = (hdr[0] << 16) | (hdr[1] << 8) | hdr[2]
                msg_length = (hdr[3] << 16) | (hdr[4] << 8) | hdr[5]
                msg_type = hdr[6]
                if td == 0xFFFFFF:
                    td = struct.unpack('>I', self.recv_exact(4))[0]
                timestamp = prev.get('timestamp', 0) + td
            elif fmt == 2:
                hdr = self.recv_exact(3)
                td = (hdr[0] << 16) | (hdr[1] << 8) | hdr[2]
                if td == 0xFFFFFF:
                    td = struct.unpack('>I', self.recv_exact(4))[0]
                timestamp = prev.get('timestamp', 0) + td
            # fmt 3: all from prev

            self.prev_headers[csid] = {
                'timestamp': timestamp,
                'msg_length': msg_length,
                'msg_type': msg_type,
                'msg_stream_id': msg_stream_id,
            }

            asm = self.assembly.get(csid, b'')
            bytes_remaining = msg_length - len(asm)
            to_read = min(bytes_remaining, self.chunk_size)

            self._trace(f"fmt={fmt} csid={csid} type={msg_type} len={msg_length} "
                        f"asm={len(asm)} to_read={to_read} chunk_size={self.chunk_size}")

            if to_read > 0:
                payload = self.recv_exact(to_read)
                asm += payload
            self.assembly[csid] = asm

            if len(asm) >= msg_length:
                del self.assembly[csid]
                complete = asm[:msg_length]

                # Apply SetChunkSize IMMEDIATELY so next read uses new size
                if msg_type == MSG_SET_CHUNK_SIZE and len(complete) >= 4:
                    new_size = struct.unpack('>I', complete[:4])[0]
                    self._trace(f"*** SetChunkSize applied: {self.chunk_size} -> {new_size}")
                    self.chunk_size = new_size

                self._trace(f"-> COMPLETE message type={msg_type} len={len(complete)}")
                return msg_type, msg_stream_id, complete, timestamp


# ─── RTMP Chunk Writer ───────────────────────────────────────────────

class ChunkWriter:
    def __init__(self, sock):
        self.sock = sock
        self.chunk_size = DEFAULT_CHUNK_SIZE

    def write_message(self, csid, msg_type, msg_stream_id, payload, timestamp=0):
        data = b''
        fmt = 0
        if csid < 64:
            data += struct.pack('B', (fmt << 6) | csid)
        elif csid < 320:
            data += struct.pack('BB', (fmt << 6) | 0, csid - 64)
        else:
            data += struct.pack('>BH', (fmt << 6) | 1, csid - 64)

        ts = min(timestamp, 0xFFFFFF)
        data += struct.pack('>I', ts)[1:]
        data += struct.pack('>I', len(payload))[1:]
        data += struct.pack('B', msg_type)
        data += struct.pack('<I', msg_stream_id)
        if ts == 0xFFFFFF:
            data += struct.pack('>I', timestamp)

        first_chunk = payload[:self.chunk_size]
        data += first_chunk
        self.sock.sendall(data)

        offset = self.chunk_size
        while offset < len(payload):
            chunk_data = b''
            if csid < 64:
                chunk_data += struct.pack('B', (3 << 6) | csid)
            elif csid < 320:
                chunk_data += struct.pack('BB', (3 << 6) | 0, csid - 64)
            else:
                chunk_data += struct.pack('>BH', (3 << 6) | 1, csid - 64)
            end = min(offset + self.chunk_size, len(payload))
            chunk_data += payload[offset:end]
            self.sock.sendall(chunk_data)
            offset = end


# ─── Mock Server ─────────────────────────────────────────────────────

class MockRTMPServer:
    def __init__(self, port=1935, fail_mode=None, enhanced=False, verbose=False):
        self.port = port
        self.fail_mode = fail_mode
        self.enhanced = enhanced
        self.verbose = verbose
        self.running = False
        self.server_socket = None
        self.stats = {
            'connections': 0,
            'audio_bytes': 0, 'video_bytes': 0,
            'audio_messages': 0, 'video_messages': 0,
            'data_messages': 0, 'start_time': None,
        }

    def log(self, msg, color=Color.RESET):
        ts = time.strftime('%H:%M:%S')
        print(f"{Color.GRAY}[{ts}]{Color.RESET} {color}{msg}{Color.RESET}")

    def log_hex(self, label, data, max_bytes=64):
        if self.verbose and data:
            hex_str = ' '.join(f'{b:02x}' for b in data[:max_bytes])
            suffix = f" ... ({len(data)} bytes)" if len(data) > max_bytes else ""
            print(f"  {Color.GRAY}[HEX] {label}: {hex_str}{suffix}{Color.RESET}")

    def start(self):
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server_socket.settimeout(1.0)
        self.server_socket.bind(('0.0.0.0', self.port))
        self.server_socket.listen(5)
        self.running = True

        mode_str = str(self.fail_mode or 'none')
        print(f"""
{Color.BOLD}╔══════════════════════════════════════════════════════╗
║          Mock RTMP Server — swift-rtmp-kit           ║
╠══════════════════════════════════════════════════════╣
║  Port:          {self.port:<37} ║
║  Fail mode:     {mode_str:<37} ║
║  Enhanced RTMP: {'yes' if self.enhanced else 'no':<37} ║
║  Verbose:       {'yes' if self.verbose else 'no':<37} ║
╠══════════════════════════════════════════════════════╣
║  URL: rtmp://localhost:{self.port}/live{' ' * (18 - len(str(self.port)))}║
║  Press Ctrl-C to stop                                ║
╚══════════════════════════════════════════════════════╝{Color.RESET}
""")

        while self.running:
            try:
                client_sock, addr = self.server_socket.accept()
                self.stats['connections'] += 1
                self.log(f"<- Connection #{self.stats['connections']} from {addr[0]}:{addr[1]}", Color.GREEN)
                t = threading.Thread(target=self._handle_client, args=(client_sock, addr), daemon=True)
                t.start()
            except socket.timeout:
                continue
            except OSError:
                break

    def stop(self):
        self.running = False
        if self.server_socket:
            self.server_socket.close()
        self._print_stats()

    def _print_stats(self):
        dur = time.time() - self.stats['start_time'] if self.stats['start_time'] else 0
        print(f"""
{Color.BOLD}-- Session Summary ------------------------------------{Color.RESET}
  Connections:     {self.stats['connections']}
  Audio messages:  {self.stats['audio_messages']} ({self._fmt_bytes(self.stats['audio_bytes'])})
  Video messages:  {self.stats['video_messages']} ({self._fmt_bytes(self.stats['video_bytes'])})
  Data messages:   {self.stats['data_messages']}
  Duration:        {dur:.1f}s
{Color.BOLD}------------------------------------------------------{Color.RESET}
""")

    @staticmethod
    def _fmt_bytes(n):
        if n < 1024: return f"{n} B"
        if n < 1024*1024: return f"{n/1024:.1f} KB"
        return f"{n/(1024*1024):.1f} MB"

    # ── Client Handler ──

    def _handle_client(self, sock, addr):
        try:
            sock.settimeout(30.0)
            reader = ChunkReader(sock, verbose=self.verbose)
            writer = ChunkWriter(sock)

            if not self._do_handshake(sock):
                return

            self.stats['start_time'] = time.time()

            while self.running:
                try:
                    msg_type, msg_stream_id, payload, timestamp = reader.read_message()
                except (ConnectionError, socket.timeout):
                    self.log(f"-> Client {addr[0]} disconnected", Color.YELLOW)
                    break

                if msg_type == MSG_SET_CHUNK_SIZE:
                    new_size = struct.unpack('>I', payload[:4])[0]
                    self.log(f"  <- Set Chunk Size: {new_size}", Color.CYAN)

                elif msg_type == MSG_WINDOW_ACK_SIZE:
                    self.log(f"  <- Window Ack Size: {struct.unpack('>I', payload[:4])[0]}", Color.CYAN)

                elif msg_type == MSG_ACK:
                    if self.verbose:
                        self.log(f"  <- Ack: {struct.unpack('>I', payload[:4])[0]}", Color.GRAY)

                elif msg_type == MSG_AMF0_COMMAND:
                    self._handle_command(writer, payload, msg_stream_id)

                elif msg_type == MSG_AMF0_DATA:
                    self.stats['data_messages'] += 1
                    try:
                        values = AMF0Decoder(payload).decode_all()
                        name = values[0] if values and isinstance(values[0], str) else "unknown"
                    except:
                        name = "unparseable"
                    self.log(f"  <- Data: {name} ({len(payload)} bytes)", Color.CYAN)

                elif msg_type == MSG_AUDIO:
                    self.stats['audio_messages'] += 1
                    self.stats['audio_bytes'] += len(payload)
                    if self.stats['audio_messages'] == 1:
                        self.log(f"  <- First audio ({len(payload)} bytes, ts={timestamp})", Color.MAGENTA)
                    elif self.stats['audio_messages'] % 100 == 0:
                        self.log(f"  <- Audio: {self.stats['audio_messages']} msgs, "
                                 f"{self._fmt_bytes(self.stats['audio_bytes'])}", Color.MAGENTA)

                elif msg_type == MSG_VIDEO:
                    self.stats['video_messages'] += 1
                    self.stats['video_bytes'] += len(payload)
                    if self.stats['video_messages'] == 1:
                        self.log(f"  <- First video ({len(payload)} bytes, ts={timestamp})", Color.BLUE)
                    elif self.stats['video_messages'] % 100 == 0:
                        self.log(f"  <- Video: {self.stats['video_messages']} msgs, "
                                 f"{self._fmt_bytes(self.stats['video_bytes'])}", Color.BLUE)

                elif msg_type == MSG_USER_CONTROL:
                    if len(payload) >= 2:
                        evt = struct.unpack('>H', payload[:2])[0]
                        self.log(f"  <- User Control: type={evt}", Color.CYAN)

                else:
                    self.log(f"  <- Unknown msg type={msg_type} len={len(payload)}", Color.GRAY)

        except Exception as e:
            self.log(f"  X Error: {e}", Color.RED)
            if self.verbose:
                import traceback
                traceback.print_exc()
        finally:
            try:
                sock.close()
            except:
                pass

    # ── Handshake ──

    def _do_handshake(self, sock):
        try:
            c0c1 = b''
            while len(c0c1) < 1 + HANDSHAKE_SIZE:
                chunk = sock.recv(1 + HANDSHAKE_SIZE - len(c0c1))
                if not chunk:
                    return False
                c0c1 += chunk

            c0_ver = c0c1[0]
            c1 = c0c1[1:1 + HANDSHAKE_SIZE]
            self.log(f"  <- C0: version={c0_ver}", Color.CYAN)
            self.log(f"  <- C1: {HANDSHAKE_SIZE} bytes", Color.CYAN)
            self.log_hex("C1", c1)

            s0 = struct.pack('B', RTMP_VERSION)
            s1_ts = struct.pack('>I', int(time.time()) & 0xFFFFFFFF)
            s1 = s1_ts + b'\x00\x00\x00\x00' + os.urandom(HANDSHAKE_SIZE - 8)

            if self.fail_mode == 'handshake':
                s2 = os.urandom(HANDSHAKE_SIZE)
                self.log(f"  -> S0+S1+S2 (CORRUPTED -- fail mode)", Color.RED)
            else:
                s2 = c1[:4] + s1_ts + c1[8:]

            sock.sendall(s0 + s1 + s2)
            self.log(f"  -> S0+S1+S2 ({1 + 2*HANDSHAKE_SIZE} bytes)", Color.GREEN)

            c2 = b''
            while len(c2) < HANDSHAKE_SIZE:
                chunk = sock.recv(HANDSHAKE_SIZE - len(c2))
                if not chunk:
                    return False
                c2 += chunk
            self.log(f"  <- C2: {HANDSHAKE_SIZE} bytes", Color.CYAN)

            self.log(f"  OK Handshake complete", Color.GREEN)
            return True

        except Exception as e:
            self.log(f"  X Handshake failed: {e}", Color.RED)
            return False

    # ── Command Handling ──

    def _handle_command(self, writer, payload, msg_stream_id):
        self.log_hex("command", payload)
        decoder = AMF0Decoder(payload)
        values = decoder.decode_all()

        if not values or not isinstance(values[0], str):
            self.log(f"  <- Unparseable command ({len(payload)} bytes)", Color.YELLOW)
            return

        cmd = values[0]
        txn = int(values[1]) if len(values) > 1 and isinstance(values[1], (int, float)) else 0
        self.log(f"  <- Command: {cmd} (txn={txn})", Color.CYAN)

        if cmd == 'connect':
            self._handle_connect(writer, values, txn)
        elif cmd == 'createStream':
            self._handle_create_stream(writer, txn)
        elif cmd == 'publish':
            self._handle_publish(writer, values, txn, msg_stream_id)
        elif cmd == 'deleteStream':
            self.log(f"    -> Stream deleted", Color.GREEN)
        elif cmd in ('releaseStream', 'FCPublish', 'FCUnpublish'):
            self.log(f"    -> (ignored)", Color.GRAY)
        else:
            self.log(f"    -> Unknown: {cmd}", Color.YELLOW)

    def _handle_connect(self, writer, values, txn):
        props = values[2] if len(values) > 2 and isinstance(values[2], dict) else {}
        app = props.get('app', 'live')
        tc_url = props.get('tcUrl', '')
        flash_ver = props.get('flashVer', '')
        four_cc = props.get('fourCcList', None)

        self.log(f"    app={app}, tcUrl={tc_url}, flash={flash_ver}", Color.CYAN)
        if four_cc:
            self.log(f"    fourCcList={four_cc} (Enhanced RTMP)", Color.MAGENTA)

        if self.fail_mode == 'auth':
            self.log(f"    -> REJECTING (fail mode: auth)", Color.RED)
            result = (amf0_encode_string('_error')
                      + amf0_encode_number(txn)
                      + amf0_encode_null()
                      + amf0_encode_object({
                          'level': 'error',
                          'code': 'NetConnection.Connect.Rejected',
                          'description': 'Connection rejected (mock auth failure)',
                      }))
            writer.write_message(3, MSG_AMF0_COMMAND, 0, result)
            return

        # Protocol control messages
        writer.write_message(2, MSG_WINDOW_ACK_SIZE, 0, struct.pack('>I', DEFAULT_WINDOW_ACK_SIZE))
        self.log(f"    -> Window Ack Size: {DEFAULT_WINDOW_ACK_SIZE}", Color.GREEN)

        writer.write_message(2, MSG_SET_PEER_BANDWIDTH, 0, struct.pack('>IB', DEFAULT_PEER_BANDWIDTH, 2))
        self.log(f"    -> Set Peer Bandwidth: {DEFAULT_PEER_BANDWIDTH}", Color.GREEN)

        new_cs = 4096
        writer.write_message(2, MSG_SET_CHUNK_SIZE, 0, struct.pack('>I', new_cs))
        writer.chunk_size = new_cs
        self.log(f"    -> Set Chunk Size: {new_cs}", Color.GREEN)

        server_props = {'fmsVer': 'MockRTMP/1.0', 'capabilities': 31.0, 'mode': 1.0}
        info = {
            'level': 'status',
            'code': 'NetConnection.Connect.Success',
            'description': 'Connection succeeded.',
            'objectEncoding': 0.0,
        }
        if self.enhanced and four_cc:
            info['fourCcList'] = four_cc
            self.log(f"    -> Enhanced RTMP negotiated", Color.MAGENTA)

        result = (amf0_encode_string('_result')
                  + amf0_encode_number(txn)
                  + amf0_encode_object(server_props)
                  + amf0_encode_object(info))
        writer.write_message(3, MSG_AMF0_COMMAND, 0, result)
        self.log(f"    -> _result: Connect.Success (txn={txn})", Color.GREEN)

    def _handle_create_stream(self, writer, txn):
        result = (amf0_encode_string('_result')
                  + amf0_encode_number(txn)
                  + amf0_encode_null()
                  + amf0_encode_number(1.0))
        writer.write_message(3, MSG_AMF0_COMMAND, 0, result)
        self.log(f"    -> _result: streamId=1 (txn={txn})", Color.GREEN)

    def _handle_publish(self, writer, values, txn, msg_stream_id):
        stream_name = values[3] if len(values) > 3 else 'unknown'
        pub_type = values[4] if len(values) > 4 else 'live'
        self.log(f"    stream={stream_name}, type={pub_type}", Color.CYAN)

        if self.fail_mode == 'publish':
            self.log(f"    -> REJECTING (fail mode: publish)", Color.RED)
            status = (amf0_encode_string('onStatus')
                      + amf0_encode_number(0)
                      + amf0_encode_null()
                      + amf0_encode_object({
                          'level': 'error',
                          'code': 'NetStream.Publish.BadName',
                          'description': f'Bad stream name: {stream_name}',
                      }))
            writer.write_message(5, MSG_AMF0_COMMAND, msg_stream_id, status)
            return

        # StreamBegin
        writer.write_message(2, MSG_USER_CONTROL, 0, struct.pack('>HI', 0, 1))

        status = (amf0_encode_string('onStatus')
                  + amf0_encode_number(0)
                  + amf0_encode_null()
                  + amf0_encode_object({
                      'level': 'status',
                      'code': 'NetStream.Publish.Start',
                      'description': f'Publishing {stream_name}',
                  }))
        writer.write_message(5, MSG_AMF0_COMMAND, msg_stream_id, status)
        self.log(f"    -> onStatus: Publish.Start", Color.GREEN)
        self.log(f"  {Color.BOLD}LIVE -- Accepting audio/video data...{Color.RESET}", Color.RED)


# ─── Main ────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='Mock RTMP Server for swift-rtmp-kit testing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                              Normal mode on port 1935
  %(prog)s --port 19350                 Custom port
  %(prog)s --fail auth                  Reject RTMP connect
  %(prog)s --fail publish               Reject publish
  %(prog)s --fail handshake             Corrupted S2
  %(prog)s --enhanced --verbose         Enhanced RTMP + debug tracing
        """)
    parser.add_argument('--port', type=int, default=1935, help='Listen port (default: 1935)')
    parser.add_argument('--fail', choices=['auth', 'publish', 'handshake'], help='Failure mode')
    parser.add_argument('--enhanced', action='store_true', help='Enhanced RTMP support')
    parser.add_argument('--verbose', '-v', action='store_true', help='Debug tracing')

    args = parser.parse_args()
    server = MockRTMPServer(port=args.port, fail_mode=args.fail,
                            enhanced=args.enhanced, verbose=args.verbose)

    def sig_handler(sig, frame):
        print(f"\n{Color.YELLOW}Shutting down...{Color.RESET}")
        server.stop()
        sys.exit(0)
    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    try:
        server.start()
    except KeyboardInterrupt:
        server.stop()
    except PermissionError:
        print(f"{Color.RED}Port {args.port} requires sudo. Try --port 19350{Color.RESET}")
        sys.exit(1)
    except OSError as e:
        print(f"{Color.RED}{e}{Color.RESET}")
        sys.exit(1)

if __name__ == '__main__':
    main()
