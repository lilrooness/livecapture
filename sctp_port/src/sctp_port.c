#include <stdlib.h>
#include <unistd.h>
#include <usrsctp.h>
#include <string.h>

int main(int argc, char **argv)
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

        // write length header (reverse endian) then data
        uint16_t len_param = 0x0800;
        write(STDOUT_FILENO, &len_param, 2);
        write(STDOUT_FILENO, "received", 8);
    }

    return 0;
}
