#!/usr/bin/env ruby

module ListComprehension
  class Comprehension < BasicObject
    def initialize(&expression)
      @expression = expression
      @env = []
      @comparisons = []
    end

    def for(&variable_declaration)
      @variable_for_next_in = get_variable_name(&variable_declaration)

      self
    end

    def in(*args, &enumerator_yielder)
      if @variable_for_next_in
        if args.length == 0 && ::Kernel.block_given?
          @env << enumerator_yielder.call.map { |val| [@variable_for_next_in, val] }
        elsif args.length == 1
          @env << args.first.map { |val| [@variable_for_next_in, val] }
        end
      end

      self
    end

    def if(&comparison)
      @comparisons << comparison

      self
    end

    def !() method_missing(:!) end
    def !=(n) method_missing(:!=, n) end
    def ==(n) method_missing(:==, n) end
    def eqal?(n) method_missing(:equal?, n) end

    private

    def get_variable_name(&variable_declaration)
      ::Class.new(BasicObject) do
        define_method(:method_missing) { |name| name }
        define_method(:name!, &variable_declaration)
      end.new.name!
    end

    def evaluate!
      return @results if @results

      expression = @expression
      first, *rest = @env
      @results = []

      first.product(*rest).each do |variable_pairs|
        result_class = ::Class.new(BasicObject) do
          variable_pairs.each do |name, value_block|
            define_method(name, -> { value_block })
          end
          define_method(:evaluate!, &expression)
        end
        result = result_class.new

        comparisons_passed = @comparisons.all? do |comparison|
          result_class.send(:define_method, :comparison?, &comparison)
          result.comparison?
        end

        @results << result.evaluate! if comparisons_passed
      end

      @results
    end

    def method_missing(name, *args, &block)
      evaluate!.public_send(name, *args, &block)
    end
  end

  def c(&block)
    Comprehension.new(&block)
  end
end
