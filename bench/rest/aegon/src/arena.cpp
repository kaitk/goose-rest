// Tier A, HttpArena's production-stack application layer:
//
//   GET  /api/items/:id    the item, and servedAt, the time in seconds
//   GET  /api/me           the user X-User-Id names, and servedAt
//   POST /api/items/:id    a body of name, price, and quantity, each optional:
//                          204, or 422; the data doesn't change
//
// An id that isn't one of the records', or isn't a number, is a 404 with an
// empty body, and a missing or unknown user a 401.

#include <span>
#include <vector>

#include <glaze/glaze.hpp>

#include "app.h"

namespace app::arena {

namespace {

struct Rating {
    int64_t score{};
    int64_t count{};
};

struct Item {
    int64_t id{};
    std::string name;
    std::string category;
    int64_t price{};
    int64_t quantity{};
    bool active{};
    std::vector<std::string> tags;
    Rating rating;
};

struct User {
    int64_t id{};
    std::string name;
    std::string email;
    std::string plan;
};

// A record with servedAt after its fields, as one JSON object, borrowing the
// record's strings.
struct ServedItem {
    int64_t id{};
    std::string_view name;
    std::string_view category;
    int64_t price{};
    int64_t quantity{};
    bool active{};
    std::span<const std::string> tags;
    Rating rating;
    uint64_t servedAt{};
};

struct ServedUser {
    int64_t id{};
    std::string_view name;
    std::string_view email;
    std::string_view plan;
    uint64_t servedAt{};
};

// A write's body: each field optional, and of its type.
struct Write {
    std::optional<std::string> name;
    std::optional<int64_t> price;
    std::optional<int64_t> quantity;
};

std::vector<Item> items;
std::vector<User> users;
// JSON=template's records, each without its closing brace.
std::vector<std::string> item_json;
std::vector<std::string> user_json;
bool template_json = false;

template <class T>
std::vector<T> parse(const std::string& dir, std::string_view name) {
    std::vector<T> out;
    std::string text = read_file(dir, name);
    if (auto ec = glz::read_json(out, text)) {
        std::fprintf(stderr, "%.*s: %s\n", int(name.size()), name.data(), glz::format_error(ec, text).c_str());
        std::exit(1);
    }
    return out;
}

template <class T>
std::string without_brace(const T& record) {
    std::string s;
    (void)glz::write_json(record, s);
    s.pop_back();
    return s;
}

// A record's response: its prebuilt JSON with servedAt spliced in.
Reply spliced(const std::string& prebuilt) {
    std::string b;
    b.reserve(prebuilt.size() + 24);
    b.append(prebuilt);
    b.append(",\"servedAt\":");
    push_int(b, static_cast<int64_t>(now_s()));
    b.push_back('}');
    return json(std::move(b));
}

template <class T>
Reply serialized(const T& view) {
    std::string b;
    (void)glz::write_json(view, b);
    return json(std::move(b));
}

Reply item(std::string_view id) {
    auto n = parse_uint(id);
    auto i = n ? index_of(*n, items.size()) : std::nullopt;
    if (!i) return not_found();
    if (template_json) return spliced(item_json[*i]);
    const Item& r = items[*i];
    return serialized(ServedItem{r.id, r.name, r.category, r.price, r.quantity, r.active, r.tags, r.rating, now_s()});
}

// The id is looked up before the body is read.
Reply write(std::string_view id, const aegon::http::Request& req) {
    auto n = parse_uint(id);
    if (!n || !index_of(*n, items.size())) return not_found();
    bool valid = is_object(req.body()) && req.json<Write>().has_value();
    return Reply::empty(valid ? 204 : 422);
}

Reply me(std::optional<std::string_view> user_id) {
    auto n = user_id ? parse_uint(*user_id) : std::nullopt;
    auto i = n ? index_of(*n, users.size()) : std::nullopt;
    if (!i) return Reply::empty(401);
    if (template_json) return spliced(user_json[*i]);
    const User& u = users[*i];
    return serialized(ServedUser{u.id, u.name, u.email, u.plan, now_s()});
}

}  // namespace

void load(const std::string& dir, bool template_) {
    template_json = template_;
    items = parse<Item>(dir, "arena-items.json");
    users = parse<User>(dir, "arena-users.json");
    if (template_json) {
        for (const auto& i : items) item_json.push_back(without_brace(i));
        for (const auto& u : users) user_json.push_back(without_brace(u));
    }
}

size_t records() {
    return items.size();
}

Reply not_found() {
    return Reply::empty(404);
}

void routes(aegon::http::Router& router) {
    router.get("/api/items/:id", [](aegon::http::Context& ctx) {
        answer(ctx, item(*ctx.req().param("id")));
    });
    router.post("/api/items/:id", [](aegon::http::Context& ctx) {
        answer(ctx, write(*ctx.req().param("id"), ctx.req()));
    });
    router.get("/api/me", [](aegon::http::Context& ctx) {
        answer(ctx, me(ctx.req().header("x-user-id")));
    });
}

}  // namespace app::arena
