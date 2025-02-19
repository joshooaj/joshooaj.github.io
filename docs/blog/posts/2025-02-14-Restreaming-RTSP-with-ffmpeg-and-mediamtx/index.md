---
date:
  created: 2025-02-19
authors:
  - joshooaj@gmail.com
categories:
  - ffmpeg
  - XProtect

links:
  - FFmpeg: https://ffmpeg.org/
  - MediaMTX: https://github.com/bluenviron/mediamtx
  - go2rtc: https://github.com/AlexxIT/go2rtc
---

# Restreaming RTSP with FFmpeg and MediaMTX

If you've ever messed with IP cameras and RTSP video feeds, you might have run into a situation where VLC can access
the stream without a problem, but the system meant to record that stream can't seem to do it. There's nothing more
permanent than a temporary fix, so in this post I'll show you (and my future self) how to work around the issue.

![hero image](../../../assets/images/universal-driver-working.png)

<!-- more -->

I am pulling an RTSP stream into XProtect, but there's nothing about this post that is exclusively for Milestone
XProtect users. The screenshot below shows the issue I was dealing with this morning. While VLC could render the video
without an issue, the universal driver in XProtect could not. The tooltip message when hovering over the camera was
"Connection is broken".

![Screenshot of Universal Driver in XProtect failing to get a video feed](universal-driver-notworking.png)

## Troubleshooting

In older versions of XProtect, it was really difficult to figure out how to turn on additional logging for the device
pack drivers for troubleshooting, but in current versions you need only look in the `C:\ProgramData\Milestone\XProtect Recording Server\Logs\Drivers`
folder for a subfolder matching the driver you're using. In my case, I took a look at the logs in the `Universal1ChAdv`
folder and found the following messages...

```plaintext title="Universal1ChAdv.log"
INFO  NmGenericCodecs::CmRTSPConnection::RtspConnect()@RTSPConnection.cpp:122	RTSP Connect: [0] [10.10.10.10]
ERROR NmRealTimeStreamProtocol::CmRtspClient<class NmHTTP::CmHTTPMessageHeaders,class NmRealTimeStreamProtocol::CmRTSPResponse>::Describe()@RtspProtocol.h:890	Failed Describe request (code=401)
INFO  NmRealTimeStreamProtocol::CmSrtpSession::CmSrtpSession()@SrtpSession.cpp:29	SRTP: srtp_init() - OK
ERROR NmRealTimeProtocol::CmQueueManager::RecieveRtpDataPacket()@RtpQueueManager.cpp:116	@@ Failed to receive RTP packet
ERROR NmMultiCodec::CmMpegCodec::DoTestTimeout()@MpegCodec.cpp:356	MPEG frame timeout expired!
ERROR NmMultiCodec::CmMultiCodec::SetErrorState()@MultiCodec.cpp:704	Setting internal error state for device [10.10.10.10:21:8554]
INFO  NmGenericCodecs::CmRTSPConnection::RtspDisconnect()@RTSPConnection.cpp:737	RTSP Disconnect: [0] [10.10.10.10]
ERROR NmMultiCodec::CmMultiCodec::CloseMediaConnectionInternal()@MultiCodec.cpp:517	Closing the current media connection!
ERROR NmRealTimeStreamProtocol::CmRTSPResponse<class NmHTTP::CmHTTPMessageHeaders>::checkSession()@Responses.h:778	checkSession - CSeq does not match (5 != 6)
ERROR NmRealTimeStreamProtocol::CmRtspClient<class NmHTTP::CmHTTPMessageHeaders,class NmRealTimeStreamProtocol::CmRTSPResponse>::Teardown()@RtspProtocol.h:587	Teardown failed (code=200)
INFO  NmRealTimeStreamProtocol::CmSrtpSession::~CmSrtpSession()@SrtpSession.cpp:53	SRTP: srtp_shutdown() - OK
INFO  CloseMediaStream()@DeviceFunctions-OSD.cpp:1251	ENTER CloseMediaStream(10.10.10.10:21:8554,0,0,0)
ERROR NmMultiCodec::CmMultiCodec::CloseMediaConnectionInternal()@MultiCodec.cpp:517	Closing the current media connection!
INFO  NmGenericCodecs::CmRTSPConnection::RtspDisconnect()@RTSPConnection.cpp:737	RTSP Disconnect: [0] [N/A]
```

Unfortunately I have no idea what I'm looking at here. All I can tell is that we attempt to connect, and fail to receive
an RTP packet. Actually, `srtp_init()` suggests to me that we're attempting to negotiate a [secure real-time transport protocol](https://en.wikipedia.org/wiki/Secure_Real-time_Transport_Protocol)
connection, and based on the following messages I guess we fail to negotiate that connection or we hit a timeout before
we receive any frames, shut down, and retry. In any case, I'm impatient so I looked to FFmpeg to solve my problems. A
quick search led me to the following FFmpeg command and arguments to "re-stream" an RTSP stream...

```plaintext title="Using FFmpeg to syndicate an RTSP feed without transcoding"
ffmpeg -rtsp_transport tcp -i "rtsp://username:password@10.10.10.10:8554/profile1" -c:v copy -f rtsp rtsp://localhost:8554/profile1
```

## Media Router

This _looked_ like it was working, but I misunderstood what FFmpeg was actually doing. I expected that it was serving up
the source stream using it's own local rtsp service on `rtsp://localhost:8554/` but that wasn't working for me. And when
I ran `netstat` or `Get-NetTcpConnection` I couldn't see any evidence that there was anything listening on `localhost:8554`.

Eventually I discovered that FFmpeg was trying to _publish_ the stream to `localhost:8554` and I needed an RTSP server
there to receive that stream and relay it. Since I'm working on a Windows server right now, I found a tool with a
Windows binary called [MediaMTX](https://github.com/bluenviron/mediamtx) that would act as a "media router". The default
configuration file included in the download for the latest release was all I needed for my purposes, but there looks to
be plenty of customization available along with options for enabling authentication for both publishing and consuming
streams.

## Transcoding

Once I fired up `ffmpeg` and `mediamtx` I was able to use VLC to connect to `rtsp://localhost:8554/profile1`, but I
was still not able to see video in XProtect. The errors in the logs were a bit different though.

```plaintext title="Universal1ChAdv.log"
INFO  NmGenericCodecs::CmRTSPConnection::RtspConnect()@RTSPConnection.cpp:122	RTSP Connect: [0] [127.0.0.1]
INFO  NmRealTimeStreamProtocol::CmSrtpSession::CmSrtpSession()@SrtpSession.cpp:29	SRTP: srtp_init() - OK
INFO  GetInfo()@DeviceFunctions-OSD.cpp:380	ENTER GetInfo(127.0.0.1:21:8080)
INFO  GetInfo()@DeviceFunctions-OSD.cpp:380	EXIT GetInfo(127.0.0.1:21:8080)
ERROR NmRealTimeProtocol::CmPayloadVideoH265::processH265Packet()@PayloadH265.cpp:175	** NOT IMPLEMENTED - CmPayloadVideoH265::processH265Packet PAYLOAD_AP ***
ERROR NmRealTimeProtocol::CmPayloadVideoH265::processAPpacket()@PayloadH265.cpp:131	** NOT IMPLEMENTED - CmPayloadVideoH265::processAPpacket ***
ERROR NmMultiCodec::CmH265Codec::DoThreadWork()@H265Codec.cpp:79	Failed to get H265 NAL packet!
ERROR NmMultiCodec::CmH265Codec::DoThreadWork()@H265Codec.cpp:100	Failed to get and process NAL packet!
ERROR NmMultiCodec::CmMultiCodec::SetErrorState()@MultiCodec.cpp:704	Setting internal error state for device [127.0.0.1:21:8080]
INFO  NmGenericCodecs::CmRTSPConnection::RtspDisconnect()@RTSPConnection.cpp:737	RTSP Disconnect: [0] [127.0.0.1]
INFO  NmRealTimeStreamProtocol::CmSrtpSession::~CmSrtpSession()@SrtpSession.cpp:53	SRTP: srtp_shutdown() - OK
INFO  NmMultiCodec::CmMultiCodec::DoGetLastMediaDataBlock()@MultiCodec.cpp:579	The connection isn't established.
INFO  CloseMediaStream()@DeviceFunctions-OSD.cpp:1251	ENTER CloseMediaStream(127.0.0.1:21:8080,0,0,0)
ERROR NmMultiCodec::CmMultiCodec::CloseMediaConnectionInternal()@MultiCodec.cpp:517	Closing the current media connection!
INFO  NmGenericCodecs::CmRTSPConnection::RtspDisconnect()@RTSPConnection.cpp:737	RTSP Disconnect: [0] [N/A]
INFO  CloseMediaStream()@DeviceFunctions-OSD.cpp:1251	EXIT CloseMediaStream(127.0.0.1:21:8080,0,0,0)
INFO  OpenMediaStream()@DeviceFunctions-OSD.cpp:1188	ENTER OpenMediaStream(127.0.0.1:21:8080,0,0,0)
INFO  OpenMediaStream()@DeviceFunctions-OSD.cpp:1188	EXIT OpenMediaStream(127.0.0.1:21:8080,0,0,0)
```

I found some suggestions online that this "Failed to get H265 NAL packet!" error could be related to a lack of support
for "aggregation packets" in XProtect's universal driver, but I'm not very well informed on the rtp/rtsp protocols and
what that actually means, so I tweaked my `ffmpeg` command a bit so that it would transcode the original h265 stream to
h264, and that worked perfectly!

```plaintext title="Using FFmpeg to syndicate an RTSP feed with transcoding"
ffmpeg -rtsp_transport tcp -i "rtsp://username:password@10.10.10.10:8554/profile1" -c:v libx264 -f rtsp rtsp://localhost:8554/profile1
```

Once I allowed FFmpeg to transcode from the source H.265 stream to H.264, XProtect was able to retrieve the stream and
my camera was finally online in the VMS.

## Alternative media router

After sharing my experience with MediaMTX with one of my coworkers, he pointed out that he has had success with a tool
called [go2rtc](https://github.com/AlexxIT/go2rtc) in the past. I haven't used it yet, but based on a quick look at the
GitHub repository, it may be a simpler, and potentially higher performance tool for the same job.

![Image representing the supported inputs and outputs for go2rtc](./go2rtc.png)

## Final thoughts

This is by no means a recommended pattern for a production system. There are numerous issues here...

1. What happens if the `ffmpeg` and/or `mediamtx` processes are terminated? Unless you wrote some tooling around this,
   you would have to re-run the commands to fire them up after a crash or a system restart. Oh, and you better not log
   out of Windows...
2. With that second `ffmpeg` command, the video is being transcoded. Depending on the build of `ffmpeg` you're using,
   it may or may not be using hardware acceleration to help with the transcoding, but either way this is adding more
   compute requirement than if the source video stream just worked in XProtect.
3. The default `mediamtx` configuration allows anyone to publish a stream, including attempting to overwrite the stream
   you are pushing from `ffmpeg`. I don't actually know what happens if a second client tries to publish the same stream
   but either way, the default configuration is not hardened and thus should never be a part of any production
   surveillance stack.
4. This was "easy" to do with one camera, but if you have 100 or 1k+ cameras, you have a lot of tooling to write to
   make the setup reliable and maintainable.

I'm sharing my notes here as I think it could be helpful in the future for myself or others while troubleshooting an
RTP/RTSP streaming issue. Knowing that `ffmpeg` can process the stream and syndicate a compatible stream is a useful
piece of information to share with, in this case, the Milestone Systems device driver team responsible for maintaining
the universal driver. Use it at your own risk!

--8<-- "abbreviations.md"
