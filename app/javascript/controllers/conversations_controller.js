import { Controller } from "@hotwired/stimulus"
import Conversations_controller from "./conversations_controller";
window.conversationChannel = conversationChannel;
// import conversationChannel from "../channels/conversation_channel"
// Connects to data-controller="conversations"
export default class extends Controller {
  connect() {
      console.log("connectes to convo controller");

  }
  scroll_to_last(){
          var panel = $('#go-to-last').parent().parent().parent().parent().parent();
          var messages_list = panel.find('.messages-list');
          // console.log(messages_list[0]);
          // console.log(messages_list.prop("scrollHeight"));
          console.log("scrolling");
          messages_list.scrollTop(messages_list.prop("scrollHeight"));
  }
  submit(e){

      console.log("connect to submit");
      console.log("i am form submit");
      e.preventDefault();
      var values = $('.new_message_form').serializeArray();
      console.log(values);
      conversationChannel.speak(values);
      console.log(conversationChannel);
      $(this).trigger('reset');

  }

  submit_by_enter(e){
      console.log("submit by enter")
      e.preventDefault();
      let form_submit = $('#submit-form');
      console.log(form_submit);
      form_submit.click();
  }
}
