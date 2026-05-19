import { DEFAULT_CAROLINE_SOCKET_URL } from "./carolineSocket";

export type DiscoveredHost = {
  url: string;
  label: string;
};

function unique(values: string[]) {
  return Array.from(new Set(values));
}

function urlFromHost(host: string) {
  // 8080 = nginx (externally reachable). Node-RED's 1880 is typically firewall-blocked.
  return `ws://${host}:8080/ws/caroline`;
}

function parseHost(url: string) {
  try {
    return new URL(url).hostname;
  } catch {
    return "";
  }
}

function likelyLocalPrefixes(defaultUrl: string) {
  const defaultHost = parseHost(defaultUrl);
  const prefixes = ["192.168.1", "192.168.12", "192.168.1", "192.168.0", "10.0.0"];

  const parts = defaultHost.split(".");
  if (parts.length === 4) {
    prefixes.unshift(parts.slice(0, 3).join("."));
  }

  return unique(prefixes);
}

function candidateUrls(defaultUrl: string) {
  const urls = [defaultUrl];
  const commonLastOctets = [47, 87, 2, 10, 20, 50, 100, 101, 150, 200, 254];

  for (const prefix of likelyLocalPrefixes(defaultUrl)) {
    for (const octet of commonLastOctets) {
      urls.push(urlFromHost(`${prefix}.${octet}`));
    }
  }

  return unique(urls);
}

function probeWebSocket(url: string, timeoutMs = 900): Promise<DiscoveredHost | null> {
  return new Promise((resolve) => {
    let settled = false;
    let socket: WebSocket | null = null;

    const finish = (host: DiscoveredHost | null) => {
      if (settled) return;
      settled = true;
      window.clearTimeout(timer);
      if (socket && socket.readyState === WebSocket.OPEN) {
        socket.close();
      }
      resolve(host);
    };

    const timer = window.setTimeout(() => finish(null), timeoutMs);

    try {
      socket = new WebSocket(url);
    } catch {
      finish(null);
      return;
    }

    socket.onopen = () => {
      // Discovery point:
      // A future Node-RED flow can reply with host metadata here, but for now
      // a successful socket connection is enough to list the host.
      finish({
        url,
        label: parseHost(url) || url
      });
    };
    socket.onerror = () => finish(null);
    socket.onclose = () => finish(null);
  });
}

export async function discoverCarolineHosts(defaultUrl = DEFAULT_CAROLINE_SOCKET_URL) {
  const candidates = candidateUrls(defaultUrl);
  const results = await Promise.all(candidates.map((url) => probeWebSocket(url)));

  return results.filter((host): host is DiscoveredHost => Boolean(host));
}
