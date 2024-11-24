/* 16-bit SUBLEQ VM with more peripherals (networking) by Richard James Howe */
#include <stdio.h>
#include <assert.h>
#include <pcap.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/stat.h>
#include <time.h>

typedef uint16_t u16;
typedef int16_t i16;
static u16 m[1<<16], prog = 0, pc = 0;

#define ETH0_MAX_PACKET_LEN (0x2000)
#define ETH0_RX_PKT_ADDR (0x8000)
#define ETH0_TX_PKT_ADDR (ETH0_RX_PKT_ADDR + ETH0_MAX_PACKET_LEN)

#if defined(unix) || defined(__unix__) || defined(__unix) || (defined(__APPLE__) && defined(__MACH__))
#include <unistd.h>
#include <termios.h>

static struct termios oldattr;

static void getch_deinit(void) {
	(void)tcsetattr(STDIN_FILENO, TCSANOW, &oldattr);
}

static int getch(void) { /* Unix junk! */
	static int terminit = 0;
	if (!terminit) {
		terminit = 1;
		if (tcgetattr(STDIN_FILENO, &oldattr) < 0) goto fail;
		struct termios newattr = oldattr;
		newattr.c_iflag &= ~(ICRNL);
		newattr.c_lflag &= ~(ICANON | ECHO);
		newattr.c_cc[VMIN]  = 0;
		newattr.c_cc[VTIME] = 0;
		if (tcsetattr(STDIN_FILENO, TCSANOW, &newattr) < 0) goto fail;
		atexit(getch_deinit);
	}
	unsigned char b = 0;
	const int ch = read(STDIN_FILENO, &b, 1) != 1 ? -1 : b;
	usleep(1000);
	if (ch == 0x1b) exit(0);
	return ch == 127 ? 8 : ch;
fail:
	exit(1);
	return 0;
}

static int putch(int c) {
	int r = putchar(c);
	if (fflush(stdout) < 0) return -1;
	return r;
}
#endif
static int pcapdev_init(const char *name, pcap_t **handle) {
	assert(handle);
	*handle = 0;
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
	if (!(*handle = pcap_open_live(device->name, 65536, 1, 10 , errbuf))) {
		(void)fprintf(stderr, "error opening %s\n", errbuf);
		goto fail;
	}
	pcap_freealldevs(devices);
	return 0;
fail:
	if (*handle)
		pcap_close(*handle);
	*handle = NULL;
	if (devices)
		pcap_freealldevs(devices);
	return -1;
}

static int dump(FILE *out, const char *banner, const unsigned char *m, size_t len) {
	assert(out);
	assert(banner);
	assert(m);
	const size_t col = 16;
	if (fprintf(stderr, "\n%s\nLEN: %d\n", banner, (int)len) < 0) return -1;
	for (size_t i = 0; i < len; i += col) {
		if (fprintf(stderr, "%04X: ", (unsigned)i) < 0) return -1;
		for (size_t j = i; j < len && j < (i + col); j++) {
			if (fprintf(stderr, "%02X ", (unsigned)m[j]) < 0) return -1;
		}
		if (fprintf(stderr, "\n") < 0) return -1;
	}
	return 0;
}

/* TODO: make non-blocking...
 * https://stackoverflow.com/questions/31305712/how-do-i-make-libpcap-pcap-loop-non-blocking
 * https://linux.die.net/man/3/pcap_dispatch */
static int eth_poll(pcap_t *handle, unsigned char *memory, int max) {
	assert(handle);
	assert(memory);
	const u_char *packet = NULL;
	struct pcap_pkthdr *header = NULL;
	if (pcap_next_ex(handle, &header, &packet) == 0) {
		return -1;
	}
	int len = header->len;
	len = len > max ? max : len;
	memcpy(&memory[ETH0_RX_PKT_ADDR], packet, len);
	dump(stdout, "ETH RX", packet, len);
	return len;
}

static int eth_transmit(pcap_t *handle, unsigned char *memory, int len) {
	assert(handle);
	assert(memory);
	return pcap_sendpacket(handle, &memory[ETH0_TX_PKT_ADDR], len);
}

static inline int isio(u16 addr) {
	i16 a = addr;
	return a <= -1 && a >= -16;
}

int main(int argc, char **argv) {
	if (setvbuf(stdout, NULL, _IONBF, 0) < 0)
		return 1;
	if (argc < 2)
		return 1;
	pcap_t *handle = NULL;
	unsigned long epoch = 0;
	int len = 0;
	if (pcapdev_init(argv[1], &handle) < 0)
		return 2;
	for (long i = 2, d = 0; i < (argc - (argc > 3)); i++) {
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
		if (isio(a)) {
			switch ((i16)a) {
			case -1: m[b] = getch(); break;
			case -2: m[b] = -eth_transmit(handle, (unsigned char *)m, len); break;
			case -3: m[b] = -eth_poll(handle, (unsigned char*)m, ETH0_MAX_PACKET_LEN); break;
			case -4: epoch = time(NULL); m[b] = -epoch; break;
			case -5: m[b] = -(epoch >> 16); break;
			}
		} else if (isio(b)) {
			switch ((i16)b) {
			case -1: if (putch(m[a]) < 0) return 5; break;
			case -2: len = m[a]; break;
			case -4: usleep(((long)m[a]) * 1000l); break;
			}
		} else {
			u16 r = m[b] - m[a];
			if (r == 0 || r & 32768)
				pc = c;
			m[b] = r;
		}
	}
	pc = -1;
	while (!m[pc])
		pc--;
	if (argc > 3) {
		FILE *f = fopen(argv[argc - 1], "wb");
		if (!f)
			return 5;
		for (unsigned i = 0; i < pc; i++)
			if (fprintf(f, "%d\n", (int16_t)m[i]) < 0) {
				(void)fclose(f);
				return 6;
			}
		if (fclose(f) < 0)
			return 7;
	}
	return 0;
}

