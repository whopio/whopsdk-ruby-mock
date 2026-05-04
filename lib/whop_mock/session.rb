# frozen_string_literal: true

module WhopMock
  class Session
    attr_reader :configuration, :dispatcher, :error_injector, :example_generator, :fallback_registry, :id_generator,
                :payment_token_store, :requester, :route_registry, :schema_registry, :spec, :store, :webhook_simulator

    def self.build(spec_path:, configuration:)
      debug_io = configuration.debug ? configuration.debug_io : nil
      spec = SpecLoader.new(spec_path, debug_io: debug_io).load
      schema_registry = SchemaRegistry.new(spec)
      route_registry = RouteRegistry.new(spec, schema_registry: schema_registry)
      store = Store.new
      fallback_registry = FallbackRegistry.new
      id_generator = IdGenerator.new(schema_registry: schema_registry, overrides: configuration.id_prefixes)
      example_generator = ExampleGenerator.new(id_generator: id_generator, schema_registry: schema_registry)
      error_injector = ErrorInjector.new
      dispatcher = Dispatcher.new(
        error_injector: error_injector,
        route_registry: route_registry,
        store: store,
        id_generator: id_generator,
        example_generator: example_generator,
        status_transitions: StatusTransitions.new,
        response_builder: ResponseBuilder.new(store: store, schema_registry: schema_registry),
        paginator: Paginator.new
      )

      new(
        configuration: configuration,
        dispatcher: dispatcher,
        debug_logger: DebugLogger.new(enabled: configuration.debug, io: configuration.debug_io),
        error_injector: error_injector,
        example_generator: example_generator,
        fallback_registry: fallback_registry,
        id_generator: id_generator,
        requester: MockRequester.new(
          dispatcher: dispatcher,
          configuration: configuration,
          debug_logger: DebugLogger.new(enabled: configuration.debug, io: configuration.debug_io),
          fallback_registry: fallback_registry
        ),
        route_registry: route_registry,
        schema_registry: schema_registry,
        spec: spec,
        store: store,
        payment_token_store: PaymentTokenStore.new(id_generator: id_generator, store: store),
        webhook_simulator: WebhookSimulator.new(example_generator: example_generator, id_generator: id_generator,
                                                store: store)
      )
    end

    def initialize(configuration:, debug_logger:, dispatcher:, error_injector:, example_generator:, fallback_registry:,
                   id_generator:, payment_token_store:, requester:, route_registry:, schema_registry:, spec:, store:, webhook_simulator:)
      @configuration = configuration
      @debug_logger = debug_logger
      @dispatcher = dispatcher
      @error_injector = error_injector
      @example_generator = example_generator
      @fallback_registry = fallback_registry
      @id_generator = id_generator
      @payment_token_store = payment_token_store
      @requester = requester
      @route_registry = route_registry
      @schema_registry = schema_registry
      @spec = spec
      @store = store
      @webhook_simulator = webhook_simulator
    end
  end
end
