CFLAGS= -g

HEADER_FILES = src

SRC =$(wildcard sctp_port/src/*.c)

OBJ = $(SRC:.c=.o)

DEFAULT_TARGETS ?= c_priv priv/c/sctp_port

priv/c/echo: c_priv $(OBJ)
  $(CC) -I $(HEADER_FILES) -o $@ $(LDFLAGS) $(OBJ) $(LDLIBS)

c_priv:
  mkdir -p priv/c

clean:
  rm -f priv/c $(OBJ) $(BEAM_FILES)