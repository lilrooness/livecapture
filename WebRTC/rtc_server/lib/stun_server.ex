defmodule StunServer do
  use GenServer

  defstruct [
    :socket
  ]

  def start_link() do
    GenServer.start(__MODULE__, [], name: __MODULE__)
  end

  def init() do
    {:ok, socket} = :gen_udp.open(19302)

    {:ok, %__MODULE__{socket: socket}}
  end
end
