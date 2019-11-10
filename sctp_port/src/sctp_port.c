#include <stdlib.h>
#include <unistd.h>
#include <usrsctp.h>
#include <string.h>

int write_fixed(char *buffer, uint16_t length)
{
    // reverse the endian of the length for the packet header
    uint16_t header_length_field = length;
    char *length_bytes = &header_length_field;
    char tmp = length_bytes[0];
    length_bytes[0] = length_bytes[1];
    length_bytes[1] = tmp;

    // write length packet header
    write(STDOUT_FILENO, &header_length_field, 2);
    return write(STDOUT_FILENO, buffer, length);
}

void read_write()
{
    char length_buffer[2];

    char read_buffer[64000];

    while (read(STDIN_FILENO, length_buffer, 2) > -1)
    {
        int tmp = length_buffer[0];
        length_buffer[0] = length_buffer[1];
        length_buffer[1] = tmp;

        // after reversing byte order, cast the char array to a uint16
        uint16_t *packet_length = length_buffer;

        read(STDIN_FILENO, read_buffer, *packet_length);

        write_fixed("received", 8);
    }

    return;
}

int main(int argc, char **argv)
{
    usrsctp_init(9899, NULL, NULL);
    // usrsctp_socket(PF_INET6, SOCK_STREAM, IPPROTO_SCTP, )

    read_write();

    usrsctp_finish();

    return 0;
}
