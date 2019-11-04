defmodule RtcServer do
  use Application

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: RtcServer.Signalling.Router,
        options: [
          dispatch: dispatch(),
          port: 4000
        ]
      ),
      Registry.child_spec(
        keys: :duplicate,
        name: Registry.RTCServer
      ),
      SCTPDebugDump.child_spec()
    ]

    opts = [strategy: :one_for_one, name: MyWebsocketApp.Application]
    Supervisor.start_link(children, opts)
  end

  defp dispatch() do
    [
      {:_,
       [
         {"/ws/[...]", RtcServer.Signalling.WSHandler, []},
         {:_, Plug.Cowboy.Handler, {RtcServer.Signalling.Router, []}}
       ]}
    ]
  end
end
