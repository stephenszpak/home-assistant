defmodule UiWeb.CoreComponents do
  use Phoenix.Component

  attr :role, :atom, required: true
  attr :text, :string, required: true
  def chat_bubble(assigns) do
    ~H"""
    <div class={[
      "w-full flex",
      if(@role == :user, do: "justify-end", else: "justify-start")
    ]}>
      <div class={[
        "max-w-[80%] rounded-2xl px-4 py-3 text-sm leading-relaxed",
        if(@role == :user, do: "bg-indigo-600 text-white", else: "bg-gray-200 text-gray-900")
      ]}>
        <%= @text %>
      </div>
    </div>
    """
  end
end

