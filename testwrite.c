#include "types.h"
#include "user.h"

int main() {
    printf(1, "[USER] calling write\n");
    write(1, "hello from write\n", 17);
    exit();
}
