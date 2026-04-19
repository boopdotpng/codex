/// Parse a first-line slash command of the form `/name <rest>`.
/// Returns `(name, rest_after_name, rest_offset)` if the line begins with `/`
/// and contains a non-empty name; otherwise returns `None`.
///
/// `rest_offset` is the byte index into the original line where `rest_after_name`
/// starts after trimming leading whitespace (so `line[rest_offset..] == rest_after_name`).
pub fn parse_slash_name(line: &str) -> Option<(&str, &str, usize)> {
    let stripped = line.strip_prefix('/')?;
    let mut name_end_in_stripped = stripped.len();
    for (idx, ch) in stripped.char_indices() {
        if ch.is_whitespace() {
            name_end_in_stripped = idx;
            break;
        }
    }
    let name = &stripped[..name_end_in_stripped];
    if name.is_empty() {
        return None;
    }
    let rest_untrimmed = &stripped[name_end_in_stripped..];
    let rest = rest_untrimmed.trim_start();
    let rest_start_in_stripped = name_end_in_stripped + (rest_untrimmed.len() - rest.len());
    let rest_offset = rest_start_in_stripped + 1;
    Some((name, rest, rest_offset))
}

/// Parse a slash command that starts at the first byte of any line in `text`.
///
/// Returns `(name, rest_after_name, rest_offset, command_offset)`. `rest_offset`
/// and `command_offset` are byte indexes into `text`.
pub fn parse_slash_name_from_any_line(text: &str) -> Option<(&str, &str, usize, usize)> {
    let mut line_start = 0;
    loop {
        if let Some((name, rest, rest_offset)) = parse_slash_name(&text[line_start..]) {
            return Some((name, rest, line_start + rest_offset, line_start));
        }

        let next_relative = text[line_start..].find('\n')?;
        line_start += next_relative + 1;
        if line_start >= text.len() {
            return None;
        }
    }
}

pub fn slash_command_rest_with_prefix(text: &str, rest: &str, command_offset: usize) -> String {
    if command_offset == 0 {
        return rest.trim().to_string();
    }

    let prefix = text[..command_offset].trim_end();
    let rest = rest.trim();
    match (prefix.is_empty(), rest.is_empty()) {
        (true, true) => String::new(),
        (true, false) => rest.to_string(),
        (false, true) => prefix.to_string(),
        (false, false) => format!("{prefix}\n{rest}"),
    }
}

#[cfg(test)]
mod tests {
    use super::parse_slash_name_from_any_line;
    use super::slash_command_rest_with_prefix;

    #[test]
    fn parse_slash_name_from_any_line_finds_lower_line_command() {
        let text = "write this down\n/goal improve pcie recovery";

        let parsed = parse_slash_name_from_any_line(text);

        assert_eq!(
            parsed,
            Some((
                "goal",
                "improve pcie recovery",
                "write this down\n/goal ".len(),
                "write this down\n".len()
            ))
        );
    }

    #[test]
    fn parse_slash_name_from_any_line_ignores_indented_slash() {
        let text = "write this down\n /goal improve pcie recovery";

        assert_eq!(parse_slash_name_from_any_line(text), None);
    }

    #[test]
    fn slash_command_rest_with_prefix_uses_text_before_lower_line_command() {
        let text = "improve pcie recovery\n/goal";
        let (_name, rest, _rest_offset, command_offset) =
            parse_slash_name_from_any_line(text).unwrap();

        assert_eq!(
            slash_command_rest_with_prefix(text, rest, command_offset),
            "improve pcie recovery"
        );
    }
}
