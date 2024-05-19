import dbus, { Message, Variant } from 'dbus-next';

export const bus = dbus.sessionBus();

export async function setRecentPlayer(name: string | null) {
	await Bun.write('/tmp/waybar-recent-player', name ?? '');
}
export async function getRecentPlayer() {
	const text = await Bun.file('/tmp/waybar-recent-player')
		.text()
		.catch(() => null);
	return text || null;
}

export class MediaPlayer {
	private player: dbus.ClientInterface;
	public properties: dbus.ClientInterface;

	constructor(private name: string, obj: dbus.ProxyObject) {
		this.player = obj.getInterface('org.mpris.MediaPlayer2.Player');
		this.properties = obj.getInterface('org.freedesktop.DBus.Properties');
	}

	static async init(name: string) {
		const obj = await bus.getProxyObject(name, '/org/mpris/MediaPlayer2');
		if (
			!obj.interfaces['org.mpris.MediaPlayer2.Player'] ||
			!obj.interfaces['org.freedesktop.DBus.Properties']
		) {
			return null;
		}
		return new MediaPlayer(name, obj);
	}

	getProperty<T>(name: string): Promise<Variant<T>> {
		return this.properties.Get('org.mpris.MediaPlayer2.Player', name);
	}

	async getPlaybackStatus() {
		const variant = await this.getProperty<'Playing' | 'Paused' | 'Stopped'>(
			'PlaybackStatus',
		);
		return variant.value;
	}
	async getMetadata() {
		const variant = await this.getProperty('Metadata');
		const metadata: PlayerMetadata = {};
		for (const [key, value] of Object.entries(
			variant.value as Record<string, Variant>,
		)) {
			metadata[key] = value.value;
		}
		return metadata;
	}
	async getPosition() {
		try {
			const variant = await this.getProperty<bigint>('Position');
			return variant.value;
		} catch (e) {
			return 0n;
		}
	}
	play() {
		return this.player.Play();
	}
	pause() {
		return this.player.Pause();
	}
	next() {
		return this.player.Next();
	}
	previous() {
		return this.player.Previous();
	}
	disconnect() {
		this.properties.removeAllListeners();
		this.player.removeAllListeners();
	}
}

export type PlayerMetadata = {
	'xesam:title'?: string;
	'xesam:artist'?: string[];
	'xesam:album'?: string;
	'mpris:length'?: bigint;
	'mpris:artUrl'?: string;
	'mpris:trackid'?: string;
	[key: string]: unknown;
};

export async function listPlayers() {
	// list players
	const listResult = await bus.call(
		new Message({
			destination: 'org.freedesktop.DBus',
			path: '/org/freedesktop/DBus',
			interface: 'org.freedesktop.DBus',
			member: 'ListNames',
		}),
	);
	if (!listResult) {
		return [];
	}
	const players: string[] =
		listResult.body[0]?.filter?.(
			(name: unknown): name is string =>
				typeof name === 'string' && name.startsWith('org.mpris.MediaPlayer2.'),
		) ?? [];
	return players;
}

export async function getPrimaryPlayer<
	T extends {
		name: string;
		status: 'Playing' | 'Paused' | 'Stopped';
	},
>(playerData: Array<T>) {
	// If one player is playing, choose that one
	// If more than one is playing, prioritize Tidal
	// If none are playing, choose the one that was most recently playing
	let primaryPlayer: (typeof playerData)[number] | undefined = undefined;
	for (const player of playerData) {
		if (player.status === 'Playing') {
			if (!primaryPlayer || player.name.includes('tidal-hifi')) {
				primaryPlayer = player;
			}
		}
	}
	if (!primaryPlayer) {
		const recentPlayer = await getRecentPlayer();
		primaryPlayer =
			playerData.find((player) => player.name === recentPlayer) ??
			playerData[0];
	}
	return primaryPlayer;
}
