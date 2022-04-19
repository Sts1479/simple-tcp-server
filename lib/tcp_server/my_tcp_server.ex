
defmodule MyTcpServer do
  use GenServer
  require Logger

  defstruct(
    active_conns: [],
    visitor: 0
  )
  @type t :: %__MODULE__{active_conns: list(port), visitor: integer}

  def clients_num_status() do
    cli = :ets.lookup(:cli_table,:cli_count)[:cli_count]
    to_string(cli) <> "\n"
  end
  def clients_num_status_upd(state) do
    cli = :ets.lookup(:cli_table,:cli_count)[:cli_count]
    if state == True do
      cli = cli + 1
      :ets.insert(:cli_table,{:cli_count,cli})
    else
      cli = cli - 1
      :ets.insert(:cli_table,{:cli_count,cli})
    end
  end

  def get_time_now() do
    to_string(DateTime.utc_now()) <> "\n"
  end

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end
  @spec init(char) :: {:ok, MyTcpServer.t()}
  def init(port) do
    case do_listen(port) do
      {true, listen_socket} ->
        Task.start_link(fn -> loop_acceptor(listen_socket) end)

      {false, errno} ->
        Logger.error(errno)
    end
    :ets.new(:cli_table, [:set, :public, :named_table])
    :ets.insert(:cli_table,{:cli_count,0})
    {:ok, %__MODULE__{}}
  end

  def handle_cast({:add_conn, client_socket}, state) do
    {:noreply,
     %{state | visitor: state.visitor + 1, active_conns: state.active_conns ++ [client_socket]}}
  end

  def handle_cast({:remove_conn, client_socket}, state) do
    {:noreply, %{state | active_conns: state.active_conns -- [client_socket]}}
  end

  def handle_call({:show_visitor_number}, _, state) do
    {:reply, state.visitor, state}
  end

  defp do_listen(port) do
    case :gen_tcp.listen(port, packet: 0, active: false) do
      {:ok, listen_socket} ->
        {true, listen_socket}

      {:error, errno} ->
        {false, errno}
    end
  end
  defp loop_acceptor(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        add_conns(client_socket)
        show_post_conn_info(client_socket)
        spawn(fn ->
          do_recv(client_socket, 0)
        end)
        loop_acceptor(listen_socket)
      {:error, errno} ->
        Logger.error(errno)
    end
  end

  defp do_recv(client_socket, length) do
    case :gen_tcp.recv(client_socket, length) do
      {:ok, data} ->
        data_handler(client_socket, data)
      {:error, :closed} ->
        Logger.info("client closed")

      {:error, errno} ->
        Logger.error(errno)
    end
  end

  defp data_handler(client_socket, data) do
    cond do
      data |> to_string |> String.trim() |> String.equivalent?("kill") ->
        do_close(client_socket)
      data |> to_string |> String.trim() |> String.equivalent?("workers") ->
        do_send(client_socket,clients_num_status())
      data |> to_string |> String.trim() |> String.equivalent?("time") ->
        do_send(client_socket,get_time_now())
      true ->
        resp = "server response: " <> to_string(data)
        do_send(client_socket, resp)
    end
  end

  defp do_send(client_socket, data) do
    case :gen_tcp.send(client_socket, data) do
      :ok ->
        do_recv(client_socket, 0)

      {:error, errno} ->
        Logger.error(errno)
    end
  end

  defp show_post_conn_info(client_socket) do
    case :inet.peername(client_socket) do
      {:ok, {address, port}} ->
        spawn(fn -> IO.inspect({show_visitor_number(), address, port}) end)

      {:error, errno} ->
        Logger.error(errno)
    end
  end

  def show_conns_info() do
    :sys.get_state(__MODULE__)
    |> Map.get(:active_conns)
    |> Enum.map(fn port -> :inet.peername(port) |> elem(1) end)
  end

  defp do_close(client_socket) do
    :gen_tcp.close(client_socket)
    remove_conns(client_socket)
  end

  def close_conns() do
    :sys.get_state(__MODULE__)
    |> Map.get(:active_conns)
    |> Enum.each(fn conn -> do_close(conn) end)
  end

  # clinetAPI

  def add_conns(client_socket) do
    clients_num_status_upd(True)
    GenServer.cast(__MODULE__, {:add_conn, client_socket})
  end

  def remove_conns(client_socket) do
    clients_num_status_upd(False)
    GenServer.cast(__MODULE__, {:remove_conn, client_socket})
  end

  @spec show_visitor_number :: any
  def show_visitor_number() do
    GenServer.call(__MODULE__, {:show_visitor_number})
  end
end
