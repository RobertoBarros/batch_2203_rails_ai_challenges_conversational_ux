class MessagesController < ApplicationController

  SYSTEM_PROMPT = <<-PROMPT
    You are a Teaching Assistant.
    I am a student at the Le Wagon AI Software Development Bootcamp, learning how to code.
    Help me break down my problem into small, actionable steps, without giving away solutions.
    Check teachers availability and answer with available teachers.
    Answer concisely in Markdown."
  PROMPT

  BATCH_NUMBER = 2203

  def create
    @chat = current_user.chats.find(params[:chat_id])
    @challenge = @chat.challenge

    @message = Message.new(message_params)
    @message.chat = @chat
    @message.role = "user"

    if @message.save

      @assistant_message = @chat.messages.create(role: "assistant", content: "")

      if @message.file.attached?
        process_file(@message.file)
      else
        send_question
      end

      @assistant_message.update(content: @response.content)
      broadcast_replace(@assistant_message)

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

  def broadcast_replace(message)
    Turbo::StreamsChannel.broadcast_replace_to(@chat, target: helpers.dom_id(message), partial: "messages/message", locals: { message: message })
  end

  def process_file(file)
    if file.content_type == "application/pdf"
      send_question(model: "gemini-2.5-flash", with: { pdf: @message.file.url })
    elsif file.image?
      send_question(model: "gpt-4o", with: { image: @message.file.url })
    elsif file.audio?
      temp_file = Tempfile.new(["audio", File.extname(@message.file.filename.to_s)])

      URI.open(@message.file.url) do |remote_file|
        IO.copy_stream(remote_file, temp_file)
      end

      send_question(model: "gpt-4o-audio-preview", with: { audio: temp_file.path })
      temp_file.unlink
    end
  end

  def send_question(model: "gpt-4.1-nano", with: {})

    available_teachers_tool = AvailableTeachersTool.new(batch_number: BATCH_NUMBER)

    provider = model.start_with?("gemini") ? "gemini" : "openai"
    @ruby_llm_chat = RubyLLM.chat.with_model(model, provider: provider, assume_exists: true)
    build_conversation_history
    @ruby_llm_chat.with_instructions(instructions)
    @ruby_llm_chat.with_tool(available_teachers_tool)

    @response = @ruby_llm_chat.ask(@message.content, with: with) do |chunk|
      next if chunk.content.blank? # skip empty chunks

      @assistant_message.content += chunk.content
      broadcast_replace(@assistant_message)
    end
  end

  def build_conversation_history
    @chat.messages.each do |message|
      next if message.content.blank?
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
    params.require(:message).permit(:content, :file)
  end
end
