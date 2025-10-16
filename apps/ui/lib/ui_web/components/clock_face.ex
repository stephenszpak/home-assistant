defmodule UiWeb.ClockFace do
  use Phoenix.Component

  attr :time_zone, :string, default: nil
  attr :show_seconds?, :boolean, default: false
  attr :use_24h?, :boolean, default: false
  attr :align, :string, default: "center" # "center" | "left"

  def clock_face(assigns) do
    ~H"""
    <section
      id="clock"
      class={[
        "h-full w-full grid bg-white text-neutral-900 dark:bg-black dark:text-white",
        if(@align == "left", do: "items-center justify-start", else: "place-items-center")
      ]}
      phx-update="ignore"
      data-tz={@time_zone}
      data-show-seconds={to_string(@show_seconds?)}
      data-use-24h={to_string(@use_24h?)}
    >
      <div class={["select-none", if(@align == "left", do: "text-left pl-6 md:pl-10", else: "text-center")]}> 
        <div class="font-medium leading-none [font-variant-numeric:tabular-nums] text-[16vw] md:text-[12vw] lg:text-[10vw]">
          <span data-role="h"></span>
          <span data-role="colon" class="blink-colon">:</span>
          <span data-role="m"></span>
          <span data-role="s" class="ml-2 text-[12vw] md:text-[9vw] lg:text-[7.5vw] align-text-top hidden"></span>
          <span data-role="ampm" class="ml-3 text-[6vw] md:text-[4.8vw] lg:text-[4vw] tracking-tight align-[0.2em]"></span>
        </div>
        <div data-role="day"  class="mt-4 tracking-[0.25em] text-xl md:text-2xl"></div>
        <div data-role="date" class="mt-1 text-lg md:text-xl opacity-80"></div>
      </div>
    </section>
    """
  end
end
