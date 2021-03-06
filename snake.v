import term
import time
import gx
import gg
import sokol.sapp
import rand
import math

// Snake Engine
enum Direction {
	pos_x
	neg_x
	pos_y
	neg_y
}

struct Point {
	x int
	y int
}

struct Bounds {
	upper_left  Point
	lower_right Point
}

struct BodyBlock {
mut:
	location         Point
	ticks_to_visible int
}

struct Snake {
	name      string
mut:
	body      []BodyBlock
	direction Direction
}

struct Game {
mut:
	snake          Snake
	last_key_press Direction
	gg             &gg.Context = voidptr(0)
}

const (
	snake_character = 'o'
	rat_character   = '@'
	tick_time_ms    = 10
	paint_factor    = 5
	x_size          = 50
	y_size          = 20
	start_position  = Point{5, 5}
	start_direction = Direction.pos_x
	bounds          = Bounds{
		upper_left: Point{1, 1}
		lower_right: Point{x_size - 1, y_size - 1}
	}
)

fn create_snake(name string, len int) Snake {
	return Snake{
		name: 'main_snake'
		body: create_tail(start_position, len)
		direction: start_direction
	}
}

fn create_tail(head Point, length int) []BodyBlock {
	default_body_block := BodyBlock{
		location: Point{0, 0}
		ticks_to_visible: 0
	}
	mut body := [default_body_block].repeat(length)
	body[0].location = head
	body[0].ticks_to_visible = 0
	mut point := head.add_x(-1)
	for i := 1; i < length; i++ {
		body[i].location = point
		point = point.add_x(-1)
	}
	return body
}

fn (s Snake) length() int {
	return s.body.len
}

pub fn (mut snake Snake) change_direction(d Direction) {
	if (snake.direction == .neg_x || snake.direction == .pos_x) && (d == .neg_x || d == .pos_x) {
	} else if (snake.direction == .neg_y ||
		snake.direction == .pos_y) &&
		(d == .neg_y || d == .pos_y) {
	} else {
		snake.direction = d
	}
}

pub fn (mut s Snake) step() {
	// update ticks
	for i := 0; i < s.length(); i++ {
		if s.body[i].ticks_to_visible > 0 {
			s.body[i].ticks_to_visible--
		}
	}
	// update positions
	// everything except the head moves according to the block before it
	for i := s.length() - 1; i >= 1; i-- {
		if s.body[i].is_visible() {
			s.body[i].location = s.body[i - 1].location
		}
	}
	// head moves according to the direction
	s.body[0].location = s.get_next_head_point()
}

fn (s Snake) get_next_head_point() Point {
	match s.direction {
		.pos_x { return s.body[0].location.add_x(1) }
		.neg_x { return s.body[0].location.add_x(-1) }
		.pos_y { return s.body[0].location.add_y(1) }
		.neg_y { return s.body[0].location.add_y(-1) }
	}
	return Point{0, 0}
}

fn (s Snake) get_visible_points() []Point {
	return s.body.filter(it.is_visible()).map(it.location)
}

fn (mut s Snake) check_snake_wrap() {
	head := s.body[0].location
	if head.x <= bounds.upper_left.x {
		s.body[0].location = Point{x_size - 2, s.body[0].location.y}
	} else if head.x >= bounds.lower_right.x {
		s.body[0].location = Point{1, s.body[0].location.y}
	} else if head.y <= bounds.upper_left.y {
		s.body[0].location = Point{s.body[0].location.x, y_size - 2}
	} else if head.y >= bounds.lower_right.y {
		s.body[0].location = Point{s.body[0].location.x, 1}
	}
}

fn (s Snake) is_dead() bool {
	return (s.body[0] in s.body[1..])
}

fn (mut s Snake) eat(rat Point) {
	tail := BodyBlock{
		location: rat
		ticks_to_visible: s.length()
	}
	s.body << tail
}

fn get_next_random_point() Point {
	return Point{rand.intn(x_size - 5) + 2, rand.intn(y_size - 5) + 2}
}

fn (s Snake) next_rat() Point {
	mut rat := get_next_random_point()
	locations := s.body.map(it.location)
	for {
		if rat in locations {
			rat = get_next_random_point()
		} else {
			return rat
		}
	}
	return rat
}

fn (b BodyBlock) is_visible() bool {
	return (b.ticks_to_visible == 0)
}

fn (arr []BodyBlock) contains(a BodyBlock) bool {
	for i := 0; i < arr.len; i++ {
		if arr[i].location.is_equal(a.location) {
			return true
		}
	}
	return false
}

fn (arr []Point) contains(a Point) bool {
	for i := 0; i < arr.len; i++ {
		if arr[i].is_equal(a) {
			return true
		}
	}
	return false
}

fn (this BodyBlock) is_equal(that BodyBlock) bool {
	return that.location.is_equal(this.location)
}

fn (p Point) add_x(value int) Point {
	return {
		p |
		x: p.x + value
	}
}

fn (p Point) add_y(value int) Point {
	return {
		p |
		y: p.y + value
	}
}

pub fn (p Point) str() string {
	return '{$p.x,$p.y}'
}

fn (this Point) is_equal(that Point) bool {
	return this.x == that.x && this.y == that.y
}

pub fn (mut g Game) run() {
	mut i := 0
	mut rat := g.snake.next_rat()
	for {
		if i == paint_factor {
			// pre paint
			i = 0
			g.snake.change_direction(g.last_key_press)
			g.snake.step()
			g.snake.check_snake_wrap()
			if g.snake.is_dead() {
				exit(0)
			}
			term.erase_clear()
			if g.snake.body[0].location.is_equal(rat) {
				g.snake.eat(rat)
				rat = g.snake.next_rat()
			}
			// paint
			point_list := g.snake.get_visible_points()
			print_point_list([rat], rat_character)
			print_point_list(point_list, snake_character)
			print_bounds()
		}
		time.sleep_ms(tick_time_ms)
		i++
	}
}

// Ascii Engine
fn print_point_list(lst []Point, ch string) {
	for point in lst {
		term.set_cursor_position(term.Coord{point.x, point.y})
		println(ch)
	}
}

fn print_line(start Point, end Point, ch string) {
	sx := start.x
	sy := start.y
	ex := end.x
	ey := end.y
	if sx == ex { // move in y
		for i := int(math.min(sy, ey)); i <= int(math.max(sy, ey)); i++ {
			term.set_cursor_position(term.Coord{sx, i})
			println(ch)
		}
	} else if sy == ey { // move in x
		for i := int(math.min(sx, ex)); i <= int(math.max(sx, ex)); i++ {
			term.set_cursor_position(term.Coord{i, sy})
			println(ch)
		}
	} else {
	}
}

fn print_bounds() {
	upper_left := bounds.upper_left
	upper_right := Point{bounds.lower_right.x, bounds.upper_left.y}
	lower_left := Point{bounds.upper_left.x, bounds.lower_right.y}
	lower_right := bounds.lower_right
	print_line(upper_right, upper_left, term.red('─'))
	print_line(lower_left, lower_right, term.red('─'))
	print_line(upper_left, lower_left, term.red('│'))
	print_line(lower_right, upper_right, term.red('│'))
}

// Main Game
fn main_game() {
	mut game := &Game{
		snake: create_snake('käärme', 10)
		last_key_press: .pos_x
		gg: 0
	}
	game.gg = gg.new_context({
		width: 10
		height: 10
		use_ortho: true
		create_window: true
		bg_color: gx.yellow
		window_title: 'snake keyboard handler'
		user_data: game
		event_fn: key_down
		frame_fn: frame
	})
	term.hide_cursor()
	go game.run()
	game.gg.run()
}

fn frame(game &Game) {
	game.gg.begin()
	game.gg.end()
}

fn key_down(e &sapp.Event, mut game Game) {
	// keys while game is running
	match e.key_code {
		.up { game.last_key_press = .neg_y }
		.left { game.last_key_press = .neg_x }
		.right { game.last_key_press = .pos_x }
		.down { game.last_key_press = .pos_y }
		else {}
	}
}

fn main() {
	main_game()
}
