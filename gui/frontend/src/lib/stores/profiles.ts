import { writable, derived } from 'svelte/store';

export interface Profile {
  id: string;
  name: string;
  host: string;
  port: number;
  key: string;
  socks_listen?: string;
  socks_user?: string;
  socks_pass?: string;
  mode?: string;
  conn?: number;
  mtu?: number;
  block?: string;
  rcvwnd?: number;
  sndwnd?: number;
  dshard?: number;
  pshard?: number;
  dscp?: number;
  smuxbuf?: number;
  streambuf?: number;
  tcpbuf?: number;
  udpbuf?: number;
  sockbuf?: number;
  local_flag?: string;
  remote_flag?: string;
  forward?: string[];
  log_level?: string;
  system_proxy?: boolean;
}

export const profiles = writable<Profile[]>([]);
export const activeProfileId = writable<string | null>(null);

export const activeProfile = derived(
  [profiles, activeProfileId],
  ([$profiles, $activeProfileId]) => {
    if (!$activeProfileId) return null;
    return $profiles.find(p => p.id === $activeProfileId) || null;
  }
);
