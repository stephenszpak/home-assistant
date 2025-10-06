defmodule UiWeb.CoreComponents do
  use Phoenix.Component

  attr :role, :atom, required: true
  attr :text, :string, required: true
  def chat_bubble(assigns) do
    text = UiWeb.Text.clean(assigns.text)
    assigns = Map.put(assigns, :_render_text, text)
    ~H"""
    <div class={[
      "w-full flex",
      if(@role == :user, do: "justify-end", else: "justify-start")
    ]}>
      <div class={[
        "max-w-[80%] rounded-2xl px-4 py-3 text-base leading-relaxed whitespace-pre-wrap break-words",
        if(@role == :user, do: "bg-indigo-600 text-white", else: "bg-gray-200 text-gray-900")
      ]}>
        <%= @_render_text %>
      </div>
    </div>
    """
  end
end
