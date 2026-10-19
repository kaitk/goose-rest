// Spike 10: a domain's file that declares its case functions in the global
// namespace, `fn ::resume`, whose bodies then resolve names there too: its
// own helpers need their namespace. See README.md.
namespace reports;

enum ::Use { None, Report { project: i64 } }

fn total(project: i64) -> i64 { project * 3600 }

fn ::resume(u: Use.None) {}
fn ::resume(u: Use.Report) { total(u.project); }

fn ::main() {
    let u: Use = Use.Report { project: 3 };
    resume(u);
}
