const std = @import("std");
const rl = @import("raylib");

const Vector2 = rl.Vector2;

const TARGET_FPS = 60;
const SCREEN_WIDTH = 600;
const SCREEN_HEIGHT = 500;
const SQUARE_LENGTH = 20;

const Snake = struct {
    head: Vector2,
    body_length: u32,
    body: std.ArrayList(Vector2),
    direction: Directions,
    arena: std.mem.Allocator,

    const Directions = enum {
        up,
        down,
        left,
        right,
    };

    fn init(arena: *std.heap.ArenaAllocator) !Snake {
        return Snake{
            .head = Vector2.init(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
            .body_length = 0,
            .body = try .initCapacity(arena.allocator(), 0),
            .direction = Directions.up,
            .arena = arena.allocator(),
        };
    }

    fn addBody(self: *Snake) !void {
        try self.body.append(self.arena, self.head); // Will be positioned properly with next move
        self.body_length += 1;
    }

    fn checkInput(self: *Snake) void {
        if (rl.isKeyPressed(.w)) {
            self.direction = .up;
        } else if (rl.isKeyPressed(.s)) {
            self.direction = .down;
        } else if (rl.isKeyPressed(.a)) {
            self.direction = .left;
        } else if (rl.isKeyPressed(.d)) {
            self.direction = .right;
        }
    }

    fn move(self: *Snake) void {
        const head_copy = self.head;
        switch (self.direction) {
            Directions.up => self.head.y -= SQUARE_LENGTH,
            Directions.down => self.head.y += SQUARE_LENGTH,
            Directions.left => self.head.x -= SQUARE_LENGTH,
            Directions.right => self.head.x += SQUARE_LENGTH,
        }
        if (self.body_length == 0) return;
        var i = self.body_length - 1;
        while (i >= 1) : (i -= 1) {
            self.body.items[i] = self.body.items[i - 1];
        }
        self.body.items[0] = head_copy;
    }

    fn borderCheck(self: *Snake) bool {
        return if ((self.head.x < 0 or self.head.x >= SCREEN_WIDTH) or (self.head.y < 0 or self.head.y >= SCREEN_HEIGHT)) true else false;
    }

    fn collisionCheck(self: *Snake, any: Vector2) bool {
        for (0..self.body_length) |i| {
            if (eqlVec2(self.body.items[i], any)) {
                return true;
            }
        }
        return false;
    }

    fn render(self: *Snake) void {
        rl.drawRectangleV(self.head, .{ .x = SQUARE_LENGTH, .y = SQUARE_LENGTH }, .green);
        for (0..self.body_length) |i| {
            rl.drawRectangleV(self.body.items[i], .{ .x = SQUARE_LENGTH, .y = SQUARE_LENGTH }, .green);
        }
    }

    fn deinit(self: *Snake) void {
        self.body_length = 0;
        self.body.deinit(self.arena);
    }
};

fn genApple(random: std.Random) Vector2 {
    return Vector2{ .x = @floatFromInt(random.uintLessThan(u32, SCREEN_WIDTH / SQUARE_LENGTH) * SQUARE_LENGTH), .y = @floatFromInt(random.uintLessThan(u32, SCREEN_HEIGHT / SQUARE_LENGTH) * SQUARE_LENGTH) };
}

fn eqlVec2(vec1: Vector2, vec2: Vector2) bool {
    if (vec1.x == vec2.x and vec1.y == vec2.y) {
        return true;
    } else {
        return false;
    }
}

fn lose(io: std.Io) noreturn {
    std.Io.File.stdout().writeStreamingAll(io, "You lose!\n") catch {};
    std.process.exit(0);
}
pub fn main(init: std.process.Init) !void {

    // INIT RANDOM (FOR APPLE GENERATION)
    const time = std.Io.Clock.now(.real, init.io).toMicroseconds();
    var prng = std.Random.DefaultPrng.init(@bitCast(time));
    const random = prng.random();
    var apple = genApple(random);

    // INIT WINDOW
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "snake game - zig");
    defer rl.closeWindow();
    rl.setTargetFPS(TARGET_FPS);

    // INIT PLAYER
    var player = try Snake.init(init.arena);
    defer player.deinit();
    try player.addBody();
    player.move();
    var tick: i8 = 0;

    while (!rl.windowShouldClose()) {

        // CHECK INPUT
        player.checkInput();

        // TICK
        tick += 1;
        if (tick >= 30) {
            player.move();
            tick = 0;
            if (player.collisionCheck(player.head) or player.borderCheck()) {
                lose(init.io);
            }
        }

        // CHECK APPLE
        if (eqlVec2(apple, player.head)) {
            try player.addBody();
            while (player.collisionCheck(apple)) {
                apple = genApple(random);
            }
        }

        // RENDER
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.black);
        rl.drawRectangleV(apple, .{ .x = SQUARE_LENGTH, .y = SQUARE_LENGTH }, .red);
        player.render();
    }
}
