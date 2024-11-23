// TODO: Cleanup after, save image also, better pcap interface, Windows raw
// mode for stdin/stdout, timer peripheral, test on Windows, optional
// non-blocking/blocking input/output
#include <stdio.h>
#include <assert.h>
#include <pcap.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/stat.h>

typedef uint16_t u16;
typedef int16_t i16;
static const u16 n = -1, net = -2, timer = -3, block = -4;
static u16 m[1<<16], prog = 0, pc = 0;

#if defined(unix) || defined(__unix__) || defined(__unix) || (defined(__APPLE__) && defined(__MACH__))
#include <unistd.h>
#include <termios.h>
int getch(void) { /* reads from keypress, doesn't echo, none blocking */
	struct termios oldattr, newattr;
	if (tcgetattr(STDIN_FILENO, &oldattr) < 0) goto fail;
	newattr = oldattr;
	newattr.c_iflag &= ~(ICRNL);
	newattr.c_lflag &= ~(ICANON | ECHO);
	newattr.c_cc[VMIN]  = 0;
	newattr.c_cc[VTIME] = 0;
	if (tcsetattr(STDIN_FILENO, TCSANOW, &newattr) < 0) goto fail;
	const int ch = getchar();
	if (tcsetattr(STDIN_FILENO, TCSANOW, &oldattr) < 0) goto fail;
	if (ch == 0x1b) exit(0);
	return ch == 127 ? 8 : ch;
fail:
	exit(1);
	return 0;
}

int putch(int c) {
	int r = putchar(c);
	if (fflush(stdout) < 0) return -1;
	return r;
}
#endif
static pcap_t *handle = NULL;
static int pcapdev_init(const char *name) {
	char errbuf[PCAP_ERRBUF_SIZE] = { 0, };
	pcap_if_t *devices = NULL;
	if (pcap_findalldevs(&devices, errbuf) == -1) {
		(void)fprintf(stderr, "error pcap_findalldevs: %s\n", errbuf);
		goto fail;
	}
	pcap_if_t *device = NULL, *found = NULL;
	for (device = devices; device; device = device->next) {
		if (!device->name)
			continue;
		int usable = 0;
		for (pcap_addr_t *addr = device->addresses; addr; addr = addr->next)
			if (addr->addr->sa_family == AF_INET)
				usable = 1;
		if (fprintf(stderr, "%s usable=%s\n", device->name, usable ? "yes" : "no") < 0)
			goto fail;
		if (!strcmp(device->name, name))
			found = device;
	}
	if (!found) {
		(void)fprintf(stderr, "device not found '%s'\n", name);
		goto fail;
	}
	device = found;
	if (!(handle = pcap_open_live(device->name, 65536, 1, 10 , errbuf))) {
		(void)fprintf(stderr, "error opening %s\n", errbuf);
		goto fail;
	}
	pcap_freealldevs(devices);
	return 0;
fail:
	if (devices)
		pcap_freealldevs(devices);
	return -1;
}

static int eth_poll(pcap_t *handle) {
	assert(handle);
	const u_char *packet = NULL;
	struct pcap_pkthdr *header = NULL;
	// TODO: Non-blocking
	while (pcap_next_ex(handle, &header, &packet) == 0)
		/* Do nothing */;
	const int len = header->len;
	assert(len < 0x2000);
	memcpy(&m[0x2000], packet, len);
	return len;
}

static void eth_transmit(pcap_t *handle, int len) {
	assert(handle);
	if ((pcap_sendpacket(handle, (unsigned char *)(&m[0x2000]), len) == -1)) {
		(void)fprintf(stderr, "pcap send error\n");
		exit(1);
	}
}

int main(int argc, char **argv) {
	if (setvbuf(stdout, NULL, _IONBF, 0) < 0)
		return 1;
//	if (pcapdev_init("lo") < 0)
//		return 2;
	for (long i = 1, d = 0; i < argc; i++) {
		FILE *f = fopen(argv[i], "rb");
		if (!f)
			return 3;
		while (fscanf(f, "%ld,", &d) > 0)
			m[prog++] = d;
		if (fclose(f) < 0)
			return 4;
	}
	for (pc = 0; pc < 32768;) {
		u16 a = m[pc++], b = m[pc++], c = m[pc++];
		// TODO: Peripherals for timer, block, network, ...
		if (a == n) {
		//if ((i16)a < 0) {
			m[b] = getchar();
			//switch ((i16)a) {
			//case -1: m[b] = getch(); break;
			//}
		//} else if ((i16)b < 0) {
		} else if (b == n) {
			putchar(m[a]);
			//if (putch(m[a]) < 0) return 5;
			//switch ((i16)b) {
			//case -1: if (putch(m[a]) < 0) return 5; break;
			//}
		} else {
			u16 r = m[b] - m[a];
			if (r == 0 || r & 32768)
				pc = c;
			m[b] = r;
		}
	}
	return 0;
}

