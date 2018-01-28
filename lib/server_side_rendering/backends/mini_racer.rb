class ServerSideRendering::Backends::MiniRacer < ServerSideRendering::Backends::Base
  def initialize(snapshot)
    @snapshot = snapshot
  end

  def render(request, component_name, props)
    context =  MiniRacer::Context.new(snapshot: @snapshot)
    result = context.eval(render_code(request, component_name, props)).html_safe
    context.dispose
    result
  end

  def self.snapshot(js_code)
    MiniRacer::Snapshot.new(context_code(js_code)).tap do |snapshot|
      snapshot.warmup!(warmup_code)
    end
  end

  private

  def self.warmup_code
    <<~JS
      (function() {
        #{gon_data}
        window.flashes = [];
        #{render_component_code('Warmup', {})}
      })()
    JS
  end
end