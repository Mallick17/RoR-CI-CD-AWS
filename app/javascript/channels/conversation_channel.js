import consumer from "channels/consumer"
const conversationChannel = consumer.subscriptions.create("ConversationChannel", {
        connected() {
                // Called when the subscription is ready for use on the server
                console.log("connected to conversation channel");
        },

        disconnected() {
            // Called when the subscription has been terminated by the server
        },

        received(data) {
                // Called when there's incoming data on the websocket for this channel
                console.log(data['message']);
                submit_messages(data);
        },

        speak: function (message) {
            console.log('speak');
            console.log(message);
            return this.perform('speak', {
                message: message
            });

        }
})
window.conversationChannel = conversationChannel;

let submit_messages;
submit_messages = function (data) {
    var conversation = $('#conversations-list').find("[data-conversation-id='" + data['conversation_id'] + "']");
    console.log('conversation')
    conversation.find('.messages-list').find('ul').append(data['message']);
    console.log("logging the appender");
    conversation.find('textarea').val('');
    var messages_list = conversation.find('.messages-list');
    var height = messages_list[0].scrollHeight;
    messages_list.scrollTop(height);
}




