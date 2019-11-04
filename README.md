# RtcServer

Implementation of an ICE-LITE WebRTC peer for streaming games to the browser

Running this project

1. Run this command from the root of the repository

```
iex -S mix
```

2. in chrome visit `http://localhost:4000/index.html`

3. Watch in awe as we succeed to do what the milestones say we have reached ...

## Debugging SCTP Packets

WebRTC wants to run SCTP over DTLS, this makes it hard to debug the SCTP packets in transit.
To get around this, the server dumps each received and sent SCTP packet to its own file inside `debug_logs/debug_dump_{packet number}`.
To convert these files into something readable by wireshark, run `./collect_logs`. This runs `hexdump -C` on each file, and appends the output
to a file called debug_hexdump in the project route. This can be imported into wireshark as an ordinary hexdump file.
Specify the encapsulation as SCTP.

Please note the SCTP handshake does not work yet, there is something wrong with my INIT ACK packets.

## Milestones

- [x] SDP Offer Exchange
- [x] Stun Binding Request + Response
- [x] DTLS Handshake
- [ ] SCTP Handshake
- [ ] WebRTC Datachannels
- [ ] SRTP Video packets FFMPEG >--[RTP]--> Elixir >--[SRTP]--> chrome
- [ ] Draw the rest of the owl...?

Big thanks to @tomciopp for the [crc32c implementation](https://gist.github.com/tomciopp/2d174f3960b6386e86167268b1a9875d)
