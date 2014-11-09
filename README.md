# List Comprehensions

I recently came across an [article](https://blog.engineyard.com/2014/ruby-list-comprehension)
about building Python-style list comprehensions in Ruby.

I thought that sounded like an interesting idea and I wanted to see how close I could
get to list comprehensions in Ruby. More specifically, I wanted to know if it was
possible to build comprehensions without doing any
parsing or using any `eval` methods. I found that it was just barely possible, but
required a number of hacky tricks.

The code I ended up with was kind of interesting.
But please don't use this code for anything in real life.

## Examples

Python:

```python
[x**2 for x in range(10)]
[(x, y) for x in [1,2,3] for y in [3,1,4] if x != y]
```

Ruby:

```ruby
c{ x ** 2 }.for{ x }.in(0...10)
c{ [x, y] }.for{ x }.in{ [1,2,3] }.for{ y }.in{ [3,1,4] }.if{ x != y }
```

## How it Works

### Chaining

The first challenge was allowing the expression to be written before the `for`, `in`, and `if`s.
For example, `c{ x ** 2 }.for{ x }.in{ 1..10 }` is a valid comprehension and `c{ x ** 2 }.for{ x }.in{ 1..10 }.if{ x < 5}`
is *also* a valid comprehension. Each method, then, needs to return an object that can act as the result of the comprehension
and at the same time act as an intermediate step in the comprehension. To handle this, the comprehension
is a subclass of `BasicObject` and is evaluated lazily.

```ruby
class Comprehension
  def for
    ...

    self
  end

  def in
    ...

    self
  end

  def if
    ...

    self
  end

  private

  def evaluate!
    ...
  end

  def method_missing(name, *args, &block)
    evaluate!.send(name, *args, &block)
  end
end
```

This allows you to use `c{ x ** 2 }.for{ x }.in{ 1..10 }` as if it were a real value, but behind the
scenes it isn't actually evaluated until it's used.

### Variable Names

The second challange was getting the name of an undefined variable from a block. Given the block
`{ x }`, I needed to somehow to pull out the symbol `:x`. I ended up doing this by creating an anonymous
class with two methods: a `method_missing` that returned the name of the method being called and a method
that executes the given block in the object's scope.

```ruby
def get_variable_name(&variable_declaration)
  ::Class.new do
    define_method(:method_missing) { |name| name }
    define_method(:name!, &variable_declaration)
  end.new.name!
end
```

Calling `get_variable_name { foo }` binds the proc `{ foo }` to
the method `name!` of an anonymous class, creates an instance of the class,
and then calls `name!`. When the proc is executed, it sees there is no local
variable named `foo` and no method named `foo` so it calls `method_missing`,
which simply returns `:foo`.

### Creating the Comprehension

The third challenge was actually creating the comprehension. This ended up being surprisingly easy
thanks to the `Array#product` method. `array.product(*arrays)` returns an array of all the
combinations of the elements in `array` and `arrays`. The only thing left now was creating an anonymous
class for each possible variable combination and evaluating the expression in an instance of each class.

```ruby
first, *rest = env
results = []

first.product(*rest).each do |variable_pairs|
  result_class = ::Class.new(BasicObject) do
    variable_pairs.each do |name, value_block|
      define_method(name, -> { value_block })
    end
    define_method(:evaluate!, &expression)
  end
  result = result_class.new

  comparisons_passed = comparisons.all? do |comparison|
    result_class.send(:define_method, :comparison?, &comparison)
    result.comparison?
  end

  results << result.evaluate! if comparisons_passed
end
```

## Caveats

Comprehensions don't work when there is a local variable defined with the same name
as the variable you're trying to use in the comprehension. For example:

```ruby
x = 10
c{ x + 1 }.for{ x }.in{ 1..4 }
```

This is because the blocks have access to local variables in the scope they were defined in.
So when `{ x }` is evaluated in the anonymous class, it never calls `method_missing`; instead
it just returns `10`.
