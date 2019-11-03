defmodule RtcServer.MuxerDemuxer do
  use GenServer

  require Logger
  require Bitwise

  @fingerprint_xor 0x5354554E

  defstruct [
    :my_sdp,
    :peer_sdp,
    :multiplexed_socket,
    :non_muxed_ports,
    :peer_ip,
    :port_map_table_id
  ]

  @udp_mtu 1460

  def start_link({my_sdp, peer_sdp, dtls_port}) do
    IO.inspect({my_sdp, peer_sdp, dtls_port})

    GenServer.start_link(
      __MODULE__,
      %{
        dtls: dtls_port,
        my_sdp: my_sdp,
        peer_sdp: peer_sdp
      },
      name: __MODULE__
    )
  end

  @impl true
  def init(%{my_sdp: my_sdp, peer_sdp: peer_sdp, dtls: dtls_port}) do
    {:ok, socket} = :gen_udp.open(9999, [{:active, true}, :binary])

    :crypto.start()

    table_id = :ets.new(:port_maps, [:set])

    {:ok,
     %__MODULE__{
       multiplexed_socket: socket,
       my_sdp: my_sdp,
       peer_sdp: peer_sdp,
       non_muxed_ports: %{dtls: dtls_port},
       port_map_table_id: table_id
     }}
  end

  def generate_stun_payload(:binding) do
    message_type = <<0x01::integer-size(16)>>
    message_length = <<0x00::integer-size(16)>>
    magic_cookie = <<0x2112A442::integer-size(32)>>
    transaction_id = <<0x4E5469735577704E4B4B7271::integer-size(96)>>

    <<message_type::binary, message_length::binary, magic_cookie::binary, transaction_id::binary>>
  end

  def generate_stun_error_response(transaction_id, attrs, hmac_key) do
    prepped_key =
      :stringprep.prepare(:erlang.binary_to_list(hmac_key)) |> :erlang.list_to_binary()

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

    hmac = :crypto.hmac(:sha1, prepped_key, integrety_check_input)

    # 24 bytes
    hmac_attr = <<0x0008::integer-size(16), 0x0014::integer-size(16), hmac::binary-size(20)>>

    fingerprint_input = <<integrety_check_input::binary, hmac_attr::binary>>

    crc_32 = Bitwise.bxor(:erlang.crc32(fingerprint_input), @fingerprint_xor)

    # 8 bytes
    fingerprint_attr =
      <<0x8028::integer-size(16), 0x0004::integer-size(16), crc_32::integer-size(32)>>

    <<fingerprint_input::binary, fingerprint_attr::binary>>
  end

  def generate_stun_success_response(
        transaction_id,
        attrs,
        hmac_key,
        _srv_reflexive_address = {rfx_ip, rfx_port}
      ) do
    prepped_key = :stringprep.prepare(:erlang.binary_to_list(hmac_key))

    message_type = <<0x0101::integer-size(16)>>
    magic_cookie = <<0x2112A442::integer-size(32)>>

    # xor_mapped_addr, hmac
    length = <<12 + 24::integer-size(16)>>

    <<xport_key::integer-size(16), _rest::binary>> = magic_cookie
    <<xaddr_key::integer-size(32)>> = magic_cookie
    x_port = Bitwise.bxor(rfx_port, xport_key)

    {p1, p2, p3, p4} = rfx_ip

    ip_blob =
      <<p1::integer-size(8), p2::integer-size(8), p3::integer-size(8), p4::integer-size(8)>>

    <<ip_whole_integer::integer-size(32)>> = ip_blob

    x_address = Bitwise.bxor(ip_whole_integer, xaddr_key)

    # always assume address family IPV4 (0x01) (attr length 96bits (12B))
    xor_mapped_address_attr =
      <<0x0020::integer-size(16), 8::integer-size(16), 0x0::integer-size(8),
        0x01::integer-size(8), x_port::integer-size(16), x_address::integer-size(32)>>

    integrety_check_input =
      <<message_type::binary, length::binary, magic_cookie::binary,
        transaction_id::integer-size(96), xor_mapped_address_attr::binary>>

    hmac = :crypto.hmac(:sha, prepped_key, integrety_check_input)

    # 24 bytes
    hmac_attr = <<0x0008::integer-size(16), 0x0014::integer-size(16), hmac::binary-size(20)>>

    # xor_mapped_addr, hmac, fingerprint
    final_length = <<12 + 24 + 8::integer-size(16)>>

    fingerprint_input =
      <<message_type::binary, final_length::binary, magic_cookie::binary,
        transaction_id::integer-size(96), xor_mapped_address_attr::binary, hmac_attr::binary>>

    crc_32 = Bitwise.bxor(:erlang.crc32(fingerprint_input), @fingerprint_xor)

    # 8 bytes
    fingerprint_attr =
      <<0x8028::integer-size(16), 0x0004::integer-size(16), crc_32::integer-size(32)>>

    <<fingerprint_input::binary, fingerprint_attr::binary>>
  end

  defp verify_message_integrity(blob, actual_hash, hmac_key) do
    prepped_key =
      :stringprep.prepare(:erlang.binary_to_list(hmac_key)) |> :erlang.list_to_binary()

    expected_hash = :crypto.hmac(:sha, hmac_key, blob)

    IO.inspect({expected_hash, byte_size(expected_hash)}, label: "calculated", limit: :infinity)
    IO.inspect({actual_hash, byte_size(actual_hash)}, label: "received", limit: :infinity)

    Logger.info("Comparing calculated Hash #{expected_hash} with received hash #{actual_hash}")

    {:ok, ^expected_hash = actual_hash}
  end

  @impl true
  def handle_info(
        {:udp, _socket, ip, src_port, data},
        %__MODULE__{
          non_muxed_ports: %{dtls: dtls_port},
          peer_ip: peer_ip,
          multiplexed_socket: socket,
          port_map_table_id: port_table_id
        } = state
      )
      when src_port == dtls_port do
    Logger.info("FORWARDING DTLS PACKET TO PEER")
    [{_key, peer_port}] = :ets.lookup(port_table_id, {:dtls, dtls_port})
    :gen_udp.send(socket, peer_ip, peer_port, data)
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, _socket, ip, src_port, data}, state) do
    %{
      multiplexed_socket: socket,
      my_sdp: my_sdp,
      peer_sdp: peer_sdp,
      port_map_table_id: port_table_id,
      non_muxed_ports: %{
        dtls: dtls_port
      }
    } = state

    # realm = "127.0.0.1"

    hmac_key = Keyword.get(my_sdp, :"ice-pwd")

    case data do
      <<22::integer-size(8), version::integer-size(16), _rest_of_dtls_client_hello::binary>>
      when version == 0xFEFF or version == 0xFEFD ->
        Logger.info("FORWARDING DTLS CLIENT HELLO PACKET")
        # set the port for dtls to be the src port for this packet so we can forward the response
        :ets.insert_new(port_table_id, {{:dtls, dtls_port}, src_port})
        :gen_udp.send(socket, {127, 0, 0, 1}, dtls_port, data)

      <<23::integer-size(8), version::integer-size(16), _rest_of_dtls_client_app_data::binary>>
      when version == 0xFEFD ->
        Logger.info("FORWARDING DTLS APPLICATION DATA")
        :ets.insert_new(port_table_id, {{:dtls, dtls_port}, src_port})
        :gen_udp.send(socket, {127, 0, 0, 1}, dtls_port, data)

      <<0x0001::integer-size(16), length::integer-size(16), 0x2112A442::integer-size(32),
        transaction_id::integer-size(96), attrs::binary>> ->
        Logger.info("REQUEST: BINDING")
        attrs_list = StunPacketAttrs.parse(attrs, length)

        reverse_byte_position =
          Keyword.get(attrs_list, :message_integrity)
          |> Map.get(:reverse_byte_position)

        hmac_hash =
          Keyword.get(attrs_list, :message_integrity)
          |> Map.get(:attr)

        hmac_input_size = byte_size(data) - reverse_byte_position

        <<hmac_input_blob::binary-size(hmac_input_size), _rest::binary>> = data

        # verify_message_integrity(
        #   hmac_input_blob,
        #   hmac_hash,
        #   hmac_key |> IO.inspect(label: "password")
        # )

        response =
          case Keyword.get(attrs_list, :ice_controlled) do
            nil ->
              Logger.info("RESPONSE: SUCCESS")

              generate_stun_success_response(
                transaction_id,
                attrs_list,
                hmac_key,
                {ip, src_port}
              )

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
        IO.inspect(data |> Base.encode16())
    end

    {:noreply, state |> Map.put(:peer_ip, ip)}
  end

  def child_spec(arg) do
    %{
      id: arg,
      start: {__MODULE__, :start_link, [arg]}
    }
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

    # byte_size(whole_packet) - reverse_byte_position == byte index of attribute (used to calculate hmac)
    reverse_byte_position = :erlang.byte_size(attrs_binary)

    # attrs are padded to the nearest multiple of 4 bytes
    padding_bytes =
      case rem(attr_length, 4) do
        0 -> 0
        r -> 4 - r
      end

    <<attr::binary-size(attr_length), rest_maybe_including_padding::binary>> = rest_including_attr

    <<_padding::binary-size(padding_bytes), rest::binary>> = rest_maybe_including_padding

    seperate_binary(rest, [
      {type_atom,
       %{attr_length: attr_length, attr: attr, reverse_byte_position: reverse_byte_position}}
      | attrs_list
    ])
  end

  def identify_attribute_type(attr_type_binary) do
    case attr_type_binary do
      0x0006 -> :username
      0xC057 -> :unknown
      0x8029 -> :ice_controlled
      0x802A -> :ice_controlling
      0x0024 -> :priority
      0x0025 -> :use_candidate
      0x0008 -> :message_integrity
      0x8028 -> :fingerprint
      0x0009 -> :error_code
      0x0020 -> :xor_mapped_address
      0x0001 -> :mapped_address
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
