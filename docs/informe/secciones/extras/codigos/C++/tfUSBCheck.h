#ifndef TFUSBCHECK_H_
#define TFUSBCKECK_H_

#include <iostream>
#include <fstream>
#include <libusb-1.0/libusb.h>
#include <cstdio>
#include <csignal>
#include <cstdlib>
#include <vector>
#include <ctime>

//errores: 9 es error, xx es el identificador del error
#define NO_DOI 			901	//Dispositivo de interes no encontrado
#define NO_PROGR 		902	//El dispositivo no se encuentra programado
#define DRIVER_BLOCKED	903	//El driver no pudo ser desconectado
#define NO_LIBUSB		904 //LIBUSB no está funcionando

//datos de Cypress
#define CY_VID			0x04b4
#define CY_FX2LP_PID	0x1003
#define OUT_EP			(LIBUSB_ENDPOINT_OUT | 8)
#define IN_EP			(LIBUSB_ENDPOINT_IN | 2)
#define INTERFACE		0

// ASCII
#define ESC 			0x1B

#define MAX_OUT_DATA	256
#define MAX_IN_DATA		512

using namespace std;

typedef struct{
	char row;
	char block;
	char check;
} err;

class USBChecker
{
private:
	struct libusb_context* ctx;
	struct libusb_device* dev;
	struct libusb_device_descriptor *dscr;
	struct libusb_device_handle* handler;
	struct libusb_transfer *transfer_out;
	struct libusb_transfer *transfer_in;


public:
	USBChecker(void);
	USBChecker(libusb_context*, libusb_device*, libusb_device_handle*);
	~USBChecker(void){}

	void init_myusb_device(void) throw(int);
	void get_usb_information(void);
	void closeChecker(void);

	void dataGenerator(unsigned char*);
	void dataChecker(unsigned char*,vector<err>*);

	void sendData(unsigned char*);

	void receiveData(unsigned char*);

	void static receive_cb(struct libusb_transfer*);
	void static send_cb(struct libusb_transfer*);


};


void static close_myusb_device(int ignored);
void err_timestamp(void);
void out_timestamp(void);

#endif //TFUSBCKECK_H_
