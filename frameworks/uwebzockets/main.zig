const std = @import("std");
const shared_mod = @import("shared_mod");
const uz = @import("uWebZockets");

pub fn main(init: std.process.Init) !void {
    var group = try uz.Server.builder(init.io)
        .preset(uz.Presets.microservice)
        .with_dev_log(false)
        .build_cluster(std.heap.page_allocator, shared_mod.thread_count, .{});
    defer group.deinit();

    const Cluster = @TypeOf(group);
    try group.configure(struct {
        fn routes(worker: *Cluster.Worker, index: usize) !void {
            _ = index;
            _ = try worker.get("/", root);
            _ = try worker.get("/httpz", httpz);
            _ = try worker.get("/api/users", users);
            _ = try worker.get("/api/users/:id", user);
            _ = try worker.post("/form", form);
            _ = try worker.post("/upload", upload);
        }
    }.routes);

    std.debug.print("Started on port {d}\n", .{shared_mod.port});
    try group.listen("0.0.0.0", shared_mod.port);
    try group.run();
}

fn root(_: *uz.Request, res: *uz.Response) void {
    res.html(shared_mod.response.hello_world) catch {};
}

fn httpz(_: *uz.Request, res: *uz.Response) void {
    res.text("OK") catch {};
}

fn users(_: *uz.Request, res: *uz.Response) void {
    var scratch: [512]u8 = undefined;
    res.json_buf(shared_mod.response.users, &scratch) catch {};
}

fn user(req: *uz.Request, res: *uz.Response) void {
    const id = std.fmt.parseInt(u32, req.get_param("id") orelse "0", 10) catch 0;

    if (id == 0 or id > shared_mod.response.users.len) {
        res.end_with_headers(
            "400 Bad Request",
            "Content-Type: application/json; charset=utf-8\r\n",
            "{\"message\":\"Invalid ID\"}",
        ) catch {};
        return;
    }

    var scratch: [256]u8 = undefined;
    res.json_buf(shared_mod.response.users[id - 1], &scratch) catch {};
}

fn form(req: *uz.Request, res: *uz.Response) void {
    const data = req.form() catch {
        res.end_with_headers("400 Bad Request", "Content-Type: text/plain\r\n", "bad form") catch {};
        return;
    };
    if (data.get("name") == null) {
        res.end_with_headers("400 Bad Request", "Content-Type: text/plain\r\n", "missing name") catch {};
        return;
    }
    res.text("OK") catch {};
}

fn upload(req: *uz.Request, res: *uz.Response) void {
    var parser = req.multipart() catch {
        res.end_with_headers("400 Bad Request", "Content-Type: text/plain\r\n", "bad multipart") catch {};
        return;
    };
    var saw_file = false;
    while (parser.next_part() catch {
        res.end_with_headers("400 Bad Request", "Content-Type: text/plain\r\n", "bad part") catch {};
        return;
    }) |part| {
        if (std.mem.eql(u8, part.name, "file") and part.filename != null) {
            saw_file = true;
            break;
        }
    }
    if (!saw_file) {
        res.end_with_headers("400 Bad Request", "Content-Type: text/plain\r\n", "missing file") catch {};
        return;
    }
    res.text("OK") catch {};
}
