#include <stdlib.h>
#include <unistd.h>
#include <usrsctp.h>

int read_fixed(char *buffer, int length)
{
    return read(STDIN_FILENO, buffer, length);
}

int main(int argc, char **argv)
{
    char length_buffer[2];

    int bytes_read = read_fixed(length_buffer, 2);

    int read_buffer[64000]; // buffer size set to UDP MTU because why not

    while (bytes_read != 0)
    {
        uint16_t *packet_length = length_buffer;
        printf("INFO: reading packet of size %d\n", *packet_length);
        int packet_bytes_read = read_fixed(read_buffer, *packet_length);
        if (packet_bytes_read != packet_length)
        {
            printf("ERROR: expected packet size: %d read: %d\n", *packet_length, packet_bytes_read);
            return 1;
        }
    }

    printf("INFO: reached EOS - ending program\n");

    return 0;
}