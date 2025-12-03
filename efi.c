#include "efi.h"

EFIAPI
EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    (void)ImageHandle;
    SystemTable->ConOut->Reset(SystemTable->ConOut, false);

    SystemTable->ConOut->ClearScreen(SystemTable->ConOut);

    SystemTable->ConOut->OutputString(SystemTable->ConOut, L"TESTING, Hello UEFI World!\r\n");

    while (1);

    return 0;    
}
