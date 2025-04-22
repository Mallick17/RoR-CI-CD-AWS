class ConversationChannel < ApplicationCable::Channel
  def subscribed
    # stream_from "some_channel"
    stream_from "conversations-#{current_user.id}"
    puts "def sub"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
    puts "def unsub"
  end

  def speak(data)
    message_params = data['message'].each_with_object({}) do |element, hash|
      hash[element.values.first] = element.values.last
    end

    puts "hi i am def speak"
    puts message_params
    # ActionCable.server.broadcast(
    #                              "conversations-#{current_user.id}",
    #                              {
    #                                title: "from conversation channel",
    #                                message: message_params
    #                              })
    # Message.create(message_params)

  end
end
