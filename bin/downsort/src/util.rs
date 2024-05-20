use anyhow::Context;
use std::{
	fs::{DirEntry, FileType},
	path::{Path, PathBuf},
};

pub struct ReadDir {
	inner: std::fs::ReadDir,
}

impl ReadDir {
	pub fn new<P>(path: P) -> std::io::Result<Self>
	where
		P: AsRef<Path>,
	{
		let inner = std::fs::read_dir(path)?;
		Ok(Self { inner })
	}
}

pub struct File {
	pub file: DirEntry,
	pub path: PathBuf,
	pub name: String,
	pub file_type: FileType,
}

impl Iterator for ReadDir {
	type Item = anyhow::Result<File>;

	fn next(&mut self) -> Option<Self::Item> {
		match self.inner.next() {
			Some(Ok(file)) => {
				let path = file.path();
				let name = file.file_name();
				let name = name.to_string_lossy();
				let file_type = file.file_type().context("Could not get file type");
				if let Err(e) = file_type {
					return Some(Err(e));
				}
				Some(Ok(File {
					file,
					path,
					name: name.into_owned(),
					file_type: file_type.unwrap(),
				}))
			}
			Some(Err(err)) => Some(Err(err.into())),
			None => None,
		}
	}
}
