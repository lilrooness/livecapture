defmodule RtcServer.MuxerDemuxer do
  use GenServer

  require Logger
  require Bitwise

  @fingerprint_xor 0x5354554E

  defstruct [
    :my_sdp,
    :peer_sdp,
    :multiplexed_socket,
    non_muxed_sockets: %{
      stun: nil,
      dtls: nil,
      srtp: nil,
      srtcp: nil
    }
  ]

  @udp_mtu 1460

  def start_link(my_sdp, peer_sdp) do
    IO.inspect({my_sdp, peer_sdp})
    GenServer.start_link(__MODULE__, %{my_sdp: my_sdp, peer_sdp: peer_sdp}, name: __MODULE__)
  end

  @impl true
  def init(%{my_sdp: my_sdp, peer_sdp: peer_sdp}) do
    {:ok, socket} = :gen_udp.open(9999, [{:active, true}, :binary])

    :crypto.start()

    {:ok, %__MODULE__{multiplexed_socket: socket, my_sdp: my_sdp, peer_sdp: peer_sdp}}
  end

  def generate_stun_payload(:binding) do
    message_type = <<0x01::integer-size(16)>>
    message_length = <<0x00::integer-size(16)>>
    magic_cookie = <<0x2112A442::integer-size(32)>>
    transaction_id = <<0x4E5469735577704E4B4B7271::integer-size(96)>>

    <<message_type::binary, message_length::binary, magic_cookie::binary, transaction_id::binary>>
  end

  def generate_stun_error_response(transaction_id, attrs, hmac_key) do
    message_type = <<0x0111::integer-size(16)>>
    magic_cookie = <<0x2112A442::integer-size(32)>>

    role_conflict_usr_message = <<"role conflict">>
    usr_msg_size = byte_size(role_conflict_usr_message)

    # error attr, hmac, fingerprint
    length = <<11 + usr_msg_size + 24 + 8::integer-size(16)>>

    conflicting_roles_error_attr =
      <<0x0009::integer-size(16), 4 + usr_msg_size::integer-size(16), <<0x0::integer-size(21)>>,
        4::integer-size(3), 87::integer-size(8), role_conflict_usr_message::bitstring,
        0x0::integer-size(24)>>

    integrety_check_input =
      <<message_type::binary, length::binary, magic_cookie::binary,
        transaction_id::integer-size(96), conflicting_roles_error_attr::binary>>

    hmac = :crypto.hmac(:sha, hmac_key, integrety_check_input)

    # 24 bytes
    hmac_attr = <<0x0008::integer-size(16), 0x0014::integer-size(16), hmac::binary-size(20)>>

    fingerprint_input = <<integrety_check_input::binary, hmac_attr::binary>>

    crc_32 = Bitwise.bxor(:erlang.crc32(fingerprint_input), @fingerprint_xor)

    # 8 bytes
    fingerprint_attr =
      <<0x8028::integer-size(16), 0x0004::integer-size(16), crc_32::integer-size(32)>>

    <<fingerprint_input::binary, fingerprint_attr::binary>>
  end

  def generate_stun_success_response(transaction_id, attrs, hmac_key) do
    message_type = <<0x0101::integer-size(16)>>
    magic_cookie = <<0x2112A442::integer-size(32)>>

    # ice_controlled, hmac, fingerprint
    length = <<12 + 24 + 8::integer-size(16)>>

    # 12 bytes
    ice_controlled =
      <<0x8029::integer-size(16), 8::integer-size(16), 0x44501A5A85F8AA03::integer-size(64)>>

    integrety_check_input =
      <<message_type::binary, length::binary, magic_cookie::binary,
        transaction_id::integer-size(96), ice_controlled::binary>>

    hmac = :crypto.hmac(:sha, hmac_key, integrety_check_input)

    # 24 bytes
    hmac_attr = <<0x0008::integer-size(16), 0x0014::integer-size(16), hmac::binary-size(20)>>

    fingerprint_input = <<integrety_check_input::binary, hmac_attr::binary>>

    crc_32 = Bitwise.bxor(:erlang.crc32(fingerprint_input), @fingerprint_xor)

    # 8 bytes
    fingerprint_attr =
      <<0x8028::integer-size(16), 0x0004::integer-size(16), crc_32::integer-size(32)>>

    <<fingerprint_input::binary, fingerprint_attr::binary>>
  end

  @impl true
  def handle_info(input, state) do
    {:udp, _socket, ip, src_port, data} = input

    %{
      multiplexed_socket: socket,
      peer_sdp: peer_sdp
      # "ice-pwd" => hmac_key
      # }
    } = state

    hmac_key = Keyword.get(peer_sdp, :"ice-pwd")

    case data do
      <<0x0001::integer-size(16), length::integer-size(16), 0x2112A442::integer-size(32),
        transaction_id::integer-size(96), attrs::binary>> ->
        Logger.info("REQUEST: BINDING")
        attrs_list = StunPacketAttrs.parse(attrs, length)

        response =
          case Keyword.get(attrs_list, :ice_controlled) do
            nil ->
              Logger.info("RESPONSE: SUCCESS")
              generate_stun_success_response(transaction_id, attrs_list, hmac_key)

            _ ->
              Logger.info("RESPONSE: ROLE CONFLICT")
              generate_stun_error_response(transaction_id, attrs_list, hmac_key)
          end

        :gen_udp.send(socket, ip, src_port, response)

      <<0x0101::integer-size(16), length::integer-size(16), 0x2112A442::integer-size(16),
        transaction_id::integer-size(96), attrs::binary>> ->
        Logger.info("STUN BINDING SUCCESS: ATTRS: #{attrs} ")

      _ ->
        Logger.info("SOMETHING ELSE IS ARRIVING")
    end

    {:noreply, state}
  end
end

defmodule StunPacketAttrs do
  require Logger

  defstruct [
    :username,
    :ice_controlled,
    :ice_controller,
    :priority,
    :message_integrity,
    :fingerprint
  ]

  def parse(attrs, _length) do
    attrs_list = seperate_binary(attrs)
    attrs_list
  end

  def seperate_binary(attrs) do
    seperate_binary(attrs, [])
  end

  def seperate_binary(<<>>, attrs_list) do
    attrs_list
  end

  def seperate_binary(attrs_binary, attrs_list) do
    <<attr_type::integer-size(16), attr_length::integer-size(16), rest_including_attr::binary>> =
      attrs_binary

    type_atom = identify_attribute_type(attr_type)

    # attrs are padded to the nearest multiple of 4 bytes
    padding_bytes =
      case rem(attr_length, 4) do
        0 -> 0
        r -> 4 - r
      end

    <<attr::binary-size(attr_length), rest_maybe_including_padding::binary>> = rest_including_attr

    <<_padding::binary-size(padding_bytes), rest::binary>> = rest_maybe_including_padding

    seperate_binary(rest, [{type_atom, {attr_length, attr}} | attrs_list])
  end

  def identify_attribute_type(attr_type_binary) do
    case attr_type_binary do
      0x0006 -> :username
      0xC057 -> :unknown
      0x8029 -> :ice_controlled
      0x0024 -> :priority
      0x0008 -> :message_integrity
      0x8028 -> :fingerprint
      0x0009 -> :error_code
    end
  end
end

defmodule StunUsernameAttr do
  defstruct [
    :length,
    :username,
    :padding
  ]
end

defmodule StunFingerprintAttr do
  defstruct [
    :length,
    :crc_32
  ]
end
