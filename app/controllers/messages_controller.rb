class MessagesController < ApplicationController

  SYSTEM_PROMPT = <<-PROMPT
    You are a Teaching Assistant.
    I am a student at the Le Wagon AI Software Development Bootcamp, learning how to code.
    Help me break down my problem into small, actionable steps, without giving away solutions.
    Answer concisely in Markdown."
  PROMPT

  def create
    @chat = current_user.chats.find(params[:chat_id])
    @challenge = @chat.challenge

    @message = Message.new(message_params)
    @message.chat = @chat
    @message.role = "user"

    if @message.save

      @ruby_llm_chat = RubyLLM.chat
      build_conversation_history

      response =  @ruby_llm_chat.with_instructions(instructions).ask(@message.content)
      Message.create(role: "assistant", content: response.content, chat: @chat)

      @chat.generate_title_from_first_message

      respond_to do |format|
        format.turbo_stream # renders `app/views/messages/create.turbo_stream.erb`
        format.html { redirect_to chat_path(@chat) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.update("new_message", partial: "messages/form", locals: { chat: @chat, message: @message }) }
        format.html { render "chats/show", status: :unprocessable_entity }
      end
    end
  end

  private

  def build_conversation_history
    @chat.messages.each do |message|
      @ruby_llm_chat.add_message(role: message.role, content: message.content)
    end
  end

  def challenge_context
    "Here is the context of the challenge: #{@challenge.content}."
  end

  def instructions
      [SYSTEM_PROMPT, challenge_context, @challenge.system_prompt].compact.join("\n\n")
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
