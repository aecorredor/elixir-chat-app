defmodule Chat.RoomChannel do
  use Chat.Web, :channel

  alias Chat.{
    Message,
    MessageView,
    Presence,
    Repo
  }

  # triggers the after_join when someone joins the room
  def join("room:lobby", _params, socket) do
    send self(), :after_join
    {:ok, socket}
  end
  def join(_other, _params, _socket) do
    {:error, "Room does not exist."}
  end

  # triggers events that happen right after a user joins a room
  # these are setting up presence tracking, and loading the 50 most
  # recent messages from the database
  def handle_info(:after_join, socket) do
    socket =
      socket
      |> track_presence
      |> send_recent_messages

    {:noreply, socket}
  end

  # handles incoming messages from clients, it inserts them into the database
  # and then broadcasts them to all users in the room using a MessageView to
  # render them properly
  def handle_in("message:new", body, socket) do
    message = Repo.insert! %Message{
      topic: socket.topic,
      user: socket.assigns.user,
      body: body
    }

    broadcast! socket,
               "message:new",
               MessageView.render("message.json", %{message: message})

    {:noreply, socket}
  end

  # updates the presence state with new socket and also starts tracking it
  defp track_presence(socket) do
    push socket, "presence_state", Presence.list(socket)
    Presence.track(socket, socket.assigns.user, %{
      online_at: :os.system_time(:milli_seconds)
    })

    socket
  end

  # gets recent messages from the database using the Message.recent function
  # It then renders all the recent messages using a MessageView to render all
  # the messages properly
  defp send_recent_messages(socket) do
    messages =
      socket.topic
      |> Message.recent
      |> Repo.all

    push socket,
         "messages:recent",
         MessageView.render("index.json", %{messages: messages})

    socket
  end
end
