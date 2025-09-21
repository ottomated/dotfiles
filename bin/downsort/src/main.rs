mod util;

use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::process::Command;
use std::str::FromStr;
use std::{env, fs::read_dir, path::PathBuf};

use anyhow::Context;
use chrono::{DateTime, Datelike, Local, Month, NaiveDate};
use filetime::{set_file_mtime, FileTime};
use regex::Regex;
use which::which;

use crate::util::ReadDir;

const MONTHS: &[&str; 12] = &[
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

#[derive(Debug, PartialEq, Eq, Hash)]
struct NaiveDay((Month, u8));

impl NaiveDay {
	pub fn from(time: NaiveDate) -> Self {
		Self((
			Month::try_from(time.month() as u8).unwrap(),
			time.day() as u8,
		))
	}
	pub fn to_folder(&self) -> String {
		format!("{} {}", MONTHS[self.0 .0 as usize], self.0 .1)
	}
	pub fn to_unix_timestamp(&self, year: i32) -> i64 {
		let month = self.0 .0 as u32;
		let day = self.0 .1;
		NaiveDate::from_ymd_opt(year, month + 1, day as u32)
			.unwrap()
			.and_hms_opt(12, 0, 0)
			.unwrap()
			.and_utc()
			.timestamp()
	}
}

type YearMap = HashMap<NaiveDay, Vec<PathBuf>>;

#[derive(Default, Debug)]
struct DownloadFolderState {
	today_files: Vec<PathBuf>,
	this_year: YearMap,
	past_years: HashMap<u16, YearMap>,
}

fn main() -> anyhow::Result<()> {
	let downloads_folder = env::args()
		.nth(1)
		.map(|folder| Ok(PathBuf::from(folder)))
		.unwrap_or_else(|| {
			home::home_dir()
				.map(|home| home.join("Downloads"))
				.context("Could not get home folder")
		})?;

	let current_state = read_current_state(&downloads_folder)?;

	let now = Local::now();
	let today = now.date_naive();

	let this_morning = today.and_hms_opt(7, 0, 0).unwrap().and_utc().timestamp();
	let this_morning = FileTime::from_unix_time(this_morning, 0);
	for file in &current_state.today_files {
		let time = FileTime::from_last_modification_time(&file.metadata()?);
		if time < this_morning {
			let res = set_file_mtime(file, this_morning);
			if let Err(err) = res {
				eprintln!("Could not set file modified time for {file:?}: {err}");
			}
		}

		// cap modification time at earliest = this midnight
	}

	let mut all_files = vec![];
	all_files.extend(current_state.today_files);
	for (_, files) in current_state.this_year {
		all_files.extend(files);
	}
	for (_, days) in current_state.past_years {
		for (_, files) in days {
			all_files.extend(files);
		}
	}

	for file in all_files {
		let target_folder = get_target_folder(&file, &downloads_folder, &today)?;
		let current_folder = file.parent().unwrap();
		if current_folder != target_folder {
			let target = target_folder.join(file.file_name().unwrap());
			// println!("{file:?} -> {target:?}");
			fs::rename(file, target)?;
		}
	}

	// Update all the folders

	let gio = which("gio").ok();

	let current_state = read_current_state(&downloads_folder)?;

	for day in current_state.this_year {
		update_day_folder(&downloads_folder, day, today.year(), &gio)?;
	}
	for (year, days) in current_state.past_years {
		let folder = downloads_folder.join(format!("old_{}", year));
		if days.is_empty() {
			// println!("Removing empty folder: {:?}", folder);
			fs::remove_dir_all(folder)?;
		} else {
			let timestamp = NaiveDate::from_ymd_opt(year as i32, 12, 31)
				.unwrap()
				.and_hms_opt(12, 0, 0)
				.unwrap()
				.and_utc()
				.timestamp();
			let time = FileTime::from_unix_time(timestamp, 0);
			set_file_mtime(&folder, time)
				.with_context(|| format!("Could not set folder modified time for {folder:?}"))?;
			turn_folder_gray(&folder, &gio);

			for day in days {
				update_day_folder(&folder, day, year as i32, &gio)?;
			}
		}
	}

	Ok(())
}

fn turn_folder_gray(folder: &Path, gio: &Option<PathBuf>) {
	let Some(gio) = gio else {
		return;
	};
	let Some(folder) = folder.to_str() else {
		return;
	};
	// println!("Turning {folder:?} gray");
	let res = Command::new(gio)
		.args([
			"set",
			folder,
			"metadata::thunar-highlight-color-foreground",
			"rgb(119, 118, 123)",
		])
		.status();
	match res {
		Ok(status) if !status.success() => {
			eprintln!("gio exited with code {status}");
		}
		Err(err) => {
			eprintln!("gio failed: {err}")
		}
		_ => {}
	}
}

fn update_day_folder(
	root: &Path,
	day: (NaiveDay, Vec<PathBuf>),
	year: i32,
	gio: &Option<PathBuf>,
) -> anyhow::Result<()> {
	let day_folder = root.join(day.0.to_folder());
	if day.1.is_empty() {
		// println!("Removing empty folder: {:?}", day_folder);
		fs::remove_dir_all(day_folder)?;
	} else {
		let timestamp = day.0.to_unix_timestamp(year);
		let time = FileTime::from_unix_time(timestamp, 0);
		turn_folder_gray(&day_folder, gio);
		set_file_mtime(&day_folder, time)
			.with_context(|| format!("Could not set folder modified time for {day_folder:?}"))?;
	}

	Ok(())
}

fn read_current_state(downloads_folder: &Path) -> anyhow::Result<DownloadFolderState> {
	let files = ReadDir::new(downloads_folder).context("Could not read downloads folder")?;

	let mut current_state = DownloadFolderState::default();

	for file in files {
		let file = file.context("Could not read file")?;

		if file.file_type.is_dir() {
			// Is this a year folder?
			if let Some(year) = is_year_folder(&file.name) {
				let (year_map, loose_files) = loop_through_year_folder(&file.path)?;
				current_state.past_years.insert(year, year_map);
				current_state.today_files.extend(loose_files);
				continue;
			}
			if let Some(day) = is_day_folder(&file.name) {
				current_state
					.this_year
					.insert(day, loop_through_day_folder(&file.path)?);
				continue;
			}
		}

		current_state.today_files.push(file.path);
	}
	Ok(current_state)
}

fn get_target_folder(file: &Path, root: &Path, today: &NaiveDate) -> anyhow::Result<PathBuf> {
	let created_at = file.metadata()?.created()?;
	let day_created: DateTime<Local> = created_at.into();
	let day_created = &day_created.date_naive();

	if day_created == today {
		Ok(root.to_path_buf())
	} else if day_created.year() == today.year() {
		let day_folder = root.join(NaiveDay::from(*day_created).to_folder());
		if !day_folder.exists() {
			fs::create_dir(&day_folder)?;
		}
		Ok(day_folder)
	} else {
		let year_folder = root.join(format!("old_{}", day_created.year()));
		if !year_folder.exists() {
			fs::create_dir(&year_folder)?;
		}
		let day_folder = year_folder.join(NaiveDay::from(*day_created).to_folder());
		if !day_folder.exists() {
			fs::create_dir(&day_folder)?;
		}
		Ok(day_folder)
	}
}

fn loop_through_year_folder(path: &Path) -> anyhow::Result<(YearMap, Vec<PathBuf>)> {
	let files = ReadDir::new(path).context("Could not read downloads folder")?;

	let mut map = HashMap::new();
	let mut loose_files = vec![];

	for file in files {
		let file = file.context("Could not read file")?;
		if file.file_type.is_dir() {
			if let Some(day) = is_day_folder(&file.name) {
				map.insert(day, loop_through_day_folder(&file.path)?);
				continue;
			}
		}
		loose_files.push(file.path);
	}
	Ok((map, loose_files))
}

fn loop_through_day_folder(path: &PathBuf) -> anyhow::Result<Vec<PathBuf>> {
	read_dir(path)
		.context("Could not read folder")
		.map(|files| {
			files
				.filter_map(|file| file.ok())
				.map(|file| file.path())
				.collect()
		})
}

fn is_year_folder(name: &str) -> Option<u16> {
	if let Some(year) = name.strip_prefix("old_") {
		year.parse::<u16>().ok()
	} else {
		None
	}
}

fn is_day_folder(name: &str) -> Option<NaiveDay> {
	let regex = Regex::new(r"[A-Z][a-z]{2} [0-9][0-9]?").unwrap();
	// Is this a day folder?
	if !regex.is_match(name) {
		return None;
	}

	let day = name[4..name.len()].parse::<u8>().ok()?;
	if day == 0 || day > 31 {
		return None;
	}

	let month = Month::from_str(&name[0..3]).ok()?;

	Some(NaiveDay((month, day)))
}
