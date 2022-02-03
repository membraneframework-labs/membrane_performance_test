defmodule PushMode.Elements.Filter do
  use Membrane.Filter

  def_input_pad :input, caps: :any, mode: :push
  def_output_pad :output, caps: :any, mode: :push
  def_options [
    id: [type: :integer, spec: pos_integer, description: "Id of the element in the pipeline"]
  ]

  @interval 100

  @impl true
  def handle_init(opts) do
    {:ok, %{id: opts.id}}
  end

  @impl true
  def handle_caps(:input, _caps, _context, state) do
    {{:ok, caps: :any}, state}
  end

  @impl true
  def handle_process(:input, buffer, _ctx, state) do
    {{:ok, [buffer: {:output, [buffer]}]}, state}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    Process.send_after(self(), :check_mailbox, @interval)
    {:ok, state}
  end

  @impl true
  def handle_other(:check_mailbox, _ctx, state) do
    mails_number = Process.info(self())[:message_queue_len]
    actions = [notify: {:mails_update, state.id, mails_number}]
    Process.send_after(self(), :check_mailbox, @interval)
    {{:ok, actions}, state}
  end
end
