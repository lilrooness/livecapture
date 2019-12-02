(() => {
  class myWebsocketHandler {
    setupSocket() {
      this.socket = new WebSocket("ws://localhost:4000/ws/chat");

      this.socket.onmessage = event => {
        const config = {
          iceServers: [{ url: "stun:stun.l.google.com:19302" }]
        };

        const offer = JSON.parse(event.data);
        console.log(offer.payload.sdp);
        let rtcPeerConnection = new window.RTCPeerConnection(config);
        rtcPeerConnection.setRemoteDescription({
          type: "offer",
          sdp: offer.payload.sdp
        });

        rtcPeerConnection.onIceCandidate = iceEvent => {
          rtcPeerConnection.addIceCandidate();
          console.log(iceEvent.target.iceGatheringState);
          this.socket.send(JSON.stringify(iceEvent));
        };

        // rtcPeerConnection.createAnswer((answer) => {
        //   rtcPeerConnection.setLocalDescription(answer);
        //   this.socket.send(answer)
        // })

        rtcPeerConnection.createAnswer().then(answer => {
          rtcPeerConnection.setLocalDescription(answer);
          this.socket.send(JSON.stringify(answer));
        });

        rtcPeerConnection.onAddStream = function(evt) {
          var remote_video_display = document.getElementById(
            "remote_video_display"
          );
          remote_video_display.src = evt.stream;
        };
      };

      this.socket.addEventListener("close", () => {
        this.setupSocket();
      });
    }

    submit(event) {
      event.preventDefault();
      const input = document.getElementById("message");
      const message = input.value;
      input.value = "";

      this.socket.send(
        JSON.stringify({
          data: { message: message }
        })
      );
    }
  }

  const websocketClass = new myWebsocketHandler();
  websocketClass.setupSocket();

  document
    .getElementById("button")
    .addEventListener("click", event => websocketClass.submit(event));
})();
