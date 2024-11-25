# SUBLEQ NETWORKING

* Author: Richard James Howe
* Project: A networking stack for a modified SUBLEQ machine running eForth
* License: 0BSD (excluding some files)
* Email: <mailto:howe.r.j.89@gmail.com>
* Repo: <https://github.com/howerj/subleq-network>

**THIS REPOSITORY IS A WORK IN PROGRESS**.

The License for the networking code is under the 0BSD, this does not cover
the files `subleq.fth` and `subleq.dec`, see <https://github.com/howerj/subleq>
for more information.

The goal of this project is to get a simple networking stack up and running for a
16-bit Forth.

# References

* <https://github.com/howerj/subleq>
* <https://github.com/samawati/j1eforth>

# To Do

* [ ] Add references, documentation, etcetera
  * [ ] Document new SUBLEQ peripherals
* [ ] Make scripts for sending/receiving data, monitoring data sent/received
* [ ] Add and test peripherals to SUBLEQ machine
* [ ] Decide on which protocols to implement (Ethernet, IP, UDP, TFTP, DNS, ARP, DHCP,
  TCP, and as clients/servers).
* [ ] Make some Forth!
* [ ] Test on Windows
  * [ ] Windows Raw Stdin/Stdout mode
* [ ] Get multiple instances talking to each other.
* [ ] Get running on an FPGA with an Ethernet card?
* [ ] Integrate with <https://github.com/howerj/ffs>
* [ ] Resolve all TODO comments
