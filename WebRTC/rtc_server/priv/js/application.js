(() => {
  class myWebsocketHandler {
    setupSocket() {
      this.socket = new WebSocket("ws://localhost:4000/ws/chat");

      this.socket.onopen = () => {
        // const config = {
        //   iceServers: [{ url: "stun:stun.l.google.com:19302" }]
        // };

        const config = {
          iceServers: [{ url: "localhost:19302" }]
        };
        let rtcPeerConnection = new window.RTCPeerConnection(config);
        // console.log(rtcPeerConnection)
        const dataChannelConfig = { ordered: true, maxRetransmits: 0 };
        let dataChannel = rtcPeerConnection.createDataChannel(
          "dc",
          dataChannelConfig
        );
        // dataChannel.onmessage = onDataChannelMessage;
        // dataChannel.onopen = onDataChannelOpen;
        const sdpConstraints = {
          mandatory: {
            OfferToReceiveAudio: true,
            OfferToReceiveVideo: true
          }
        };

        const onOfferCreated = description => {
          rtcPeerConnection.setLocalDescription(description);
          window.rtcOffer = description;
          // this.socket.send("something!")
          this.socket.send(
            JSON.stringify({ type: "offer", payload: description })
          );
        };
        //
        const onIceCandidate = event => {
          console.log(event.target.iceGatheringState);
          if (event.candidate) {
            console.log(event.candidate);
            this.socket.send(JSON.stringify(event.candidate));
          }
        };

        rtcPeerConnection.onicecandidate = onIceCandidate;
        rtcPeerConnection.createOffer(onOfferCreated, () => { }, sdpConstraints);
      };

      // this.socket.addEventListener("message", (event) => {
      //     const pTag = document.createElement("p")
      //     pTag.innerHTML = event.data

      //     document.getElementById("main").append(pTag)
      // })

      // this.socket.addEventListener("close", () => {
      //     this.setupSocket()
      // })
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
