//============================================================================
// Name        : tfUSBCheck.cpp
// Author      : Edwin Barragan
// Version     :
// Copyright   : My final degree work
// Description : Hello World in C++, Ansi-style
//============================================================================


//TODO	hay que hacer un script que programe el dispositivo
//TODO	todavía no realiza comunicación alguna

//Pasos a seguir según
/*https://www.dreamincode.net/forums
 * /topic/148707-introduction-to-using-libusb-10
 * /page__p__885389__hl__USB__fromsearch__1#entry885389*/

/* initialize the library by calling the function libusb_init and creating a session
 * Call the function libusb_get_device_list to get a list of connected devices. This creates an array of libusb_device containing all USB devices connected to the system.
 * Discover the one and open the device either by libusb_open or libusb_open_device_with_vid_pid(when you know vendor and product id of the device) to open the device
 * Clear the list you got from libusb_get_device_list by using libusb_free_device_list
 * Claim the interface with libusb_claim_interface (requires you to know the interface numbers of device)
 * Do desired I/O
 * Release the device by using libusb_release_interface
 * Close the device you opened before, by using libusb_close
 * Close the session by using libusb_exit*/



#include "tfUSBCheck.h"
bool to_exit = 1;
bool to_send = 1;
bool to_receive = 0;
bool to_check = 0;
bool to_log = 0;
int actual_length = 1;

USBChecker::USBChecker(void){
	ctx = NULL;
	dev = NULL;
	dscr = NULL;
	handler = NULL;
	transfer_in = NULL;
	transfer_out = NULL;
}

void USBChecker::closeChecker(void){
	if(transfer_out)
		libusb_cancel_transfer(transfer_out);
	if(transfer_in)
		libusb_cancel_transfer(transfer_in);
	libusb_release_interface(handler, INTERFACE);
}

USBChecker::USBChecker(libusb_context* context, libusb_device* device, libusb_device_handle * hand){
	ctx = context;
	dev = device;
	handler = hand;
	dscr = NULL;
	transfer_in = NULL;
	transfer_out = NULL;
}

void USBChecker::init_myusb_device(void) throw(int){

	int is_not_ok;
	libusb_device **list;
	ssize_t cont;
	ssize_t dev_idx;

	// initialize the library by calling the function libusb_init and creating a session
	//inicialización del usb
	is_not_ok = libusb_init(&ctx);
	if(is_not_ok)
	{
		err_timestamp();
		cerr << "No funciona libusb" << endl;
		throw(NO_LIBUSB);
	}
	libusb_set_debug(ctx, LIBUSB_LOG_LEVEL_DEBUG); 	//todos los msjs serán mostrados en el archivo
													// registro de eventos

	// Call the function libusb_get_device_list to get a list of connected devices.
	// This creates an array of libusb_device containing all USB devices connected to the system.
	//discover devices
	cont = libusb_get_device_list(ctx, &list);
	// Loop through all these devices and check their options
	for(dev_idx = 0; dev_idx < cont; dev_idx++)
	{
		libusb_device *aux_dev = list[dev_idx];
		libusb_device_descriptor aux_dscr;

		//getting descriptor
		is_not_ok = libusb_get_device_descriptor(aux_dev, &aux_dscr);

		if(is_not_ok)
		{
			err_timestamp();
			cerr << "No pude acceder a un descriptor" << endl;
		}

		// Discover the one
		if(aux_dscr.idVendor == CY_VID)
		{
			if(aux_dscr.idProduct == CY_FX2LP_PID)
			{
				dev = aux_dev;
				dscr = &aux_dscr;
			}
			else
			{
				err_timestamp();
				cerr << "El dispositivo no se encuentra programado" << endl;
				throw(NO_PROGR);
			}
		}

	}

	if(dev == NULL)
	{
		cerr << "No se encuentra el dispositivo" << endl;
		throw(NO_DOI);
	}

	// Discover the one and open the device either by
	// libusb_open or
	// libusb_open_device_with_vid_pid(when you know vendor and product id of the device)
	// to open the device
	//open my device
	handler = libusb_open_device_with_vid_pid(ctx, CY_VID, CY_FX2LP_PID);

	// Clear the list you got from libusb_get_device_list by using libusb_free_device_list
	libusb_free_device_list(list, 1);
	//devices discovered
	// Claim the interface with
	//libusb_claim_interface (requires you to know the interface numbers of device)
		//first i have to detach the device driver to the kernel.
		//doing this automatically
	is_not_ok = libusb_set_auto_detach_kernel_driver(handler, 1);
	if(is_not_ok)
	{
		cerr << "detached failed" << endl;
		throw(DRIVER_BLOCKED);
	}
	libusb_claim_interface(handler, INTERFACE);
	libusb_set_interface_alt_setting(handler,0,0);
	//para debug
	out_timestamp();
	cout << "Tengo control sobre la placa" << endl;
}


void /*USBChecker::*/close_myusb_device(int ignored){
	cout << "Sali con la señal " << ignored << endl;
	to_exit = 0;
}

void USBChecker::dataGenerator(unsigned char* data){
	char number;
	unsigned char block = 0, bit;
	uint row;
	uint i;
	char rowParity = 0, colParity = 0;
	const char mask = 0x01;

	while(block <= MAX_OUT_DATA / 8)
	{
		i = block * 8;
		colParity = 0;
		for(row = i; row < i + 7; row++)
		{
			rowParity = 0;
			number = char(rand() & 0x7f);
			data[row] = number << 1;
			for(bit = 0; bit < 7; bit++)
			{
				rowParity = rowParity ^ (number & mask);
				number = number >> 1;
			}
			if(rowParity)
				data[row] = data[row] | 0x01;
			else
				data[row] = data[row] & 0xF7;
			colParity = colParity ^ data[row];
		}
		data[row] = colParity;
		block++;
	}
	//para debug
//	out_timestamp();
//	cout << "Generé datos aleatorios:" << endl;
//	for(i = 0; i < MAX_OUT_DATA;i++)
//	{
//		if(i%16 == 15)
//			cout << (int)data[i] << endl;
//		else
//			cout << (int)data[i] << '\t';
//	}
}

void USBChecker::dataChecker(unsigned char* data,vector<err> *errores){
	unsigned char block = 0, bit;
	uint row;
	char mask = 0x01;

	cout << "Estoy en el checker" << endl;
	while(block < actual_length/8)
	{
		err error;
		error.block = 0;
		error.row = 0;
		error.check = 0;
		uint i = block * 8;
		char colParity = 0;
		for(row = i; row < i + 8; row++)
		{
			char rowParity = 0;
			char aux_data = data[row];
			for(bit = 0; bit < 8; bit++)
			{
				rowParity = rowParity ^ (aux_data & mask);
				aux_data >>= 1;
			}
			if(!(rowParity))
			{
				error.row = row;
				errores->push_back(error);
			}
			colParity ^= data[row];
		}
		if(!colParity)
		{
			error.block = block;
			error.check = colParity;
			errores->push_back(error);
		}
	}
	to_log = 1;
	cout << "sali del Checker" << endl;
}

void USBChecker::sendData(unsigned char* data){
	transfer_out = libusb_alloc_transfer(0);
//	int esta=0;
	libusb_fill_bulk_transfer(transfer_out,handler,OUT_EP,data,MAX_OUT_DATA,send_cb,NULL,0);
//	if(libusb_bulk_transfer(handler,OUT_EP,data,MAX_OUT_DATA,&esta,60000))
//		cout << "buenisimo" << endl;
//	else
//		cout << "malisimo" << endl;
	int c = libusb_submit_transfer(transfer_out);
	out_timestamp();
	cout << "Mandé datos " << c << endl;

}

void USBChecker::send_cb(struct libusb_transfer* transfer){
	out_timestamp();
	cout << "Estoy en el callback de envío" << endl;
	cout << transfer->status << endl;
	switch(transfer->status)
	{
		case LIBUSB_TRANSFER_COMPLETED:
			to_receive = 1;
			break;
		case LIBUSB_TRANSFER_ERROR:
			break;
		case LIBUSB_TRANSFER_TIMED_OUT:
			err_timestamp();
			cerr << "El dispositivo no responde." << endl;
			to_exit = 0;
			//timers libres. no ocurriría
			break;
		case LIBUSB_TRANSFER_CANCELLED:
			//no prgramado para que ocurra
			break;
		case LIBUSB_TRANSFER_STALL:
			//no programado para que ocurra
			break;
		case LIBUSB_TRANSFER_NO_DEVICE:
			//si se desconecta el dispositivo
			err_timestamp();
			cerr << "El dispositivo se desconectó. Se cierra programa." << endl;
			to_exit = 0;
			return;
		case LIBUSB_TRANSFER_OVERFLOW:
			err_timestamp();
			cerr << "Fallo por overflow. Revisar código de generacion de datos. Se cierra programa." << endl;
			to_exit = 0;
			break;
		default:
			break;
	}
	libusb_free_transfer(transfer);
}

void USBChecker::receiveData(unsigned char* data){
	int pktSize;
	int isoPkts = 1;
	transfer_in = libusb_alloc_transfer(isoPkts);
	pktSize = libusb_get_max_iso_packet_size(dev,IN_EP);
	libusb_fill_iso_transfer(transfer_in,handler,IN_EP,data,pktSize,isoPkts,receive_cb,NULL,0);
	libusb_set_iso_packet_lengths(transfer_in,pktSize);
//    transfer_in->flags = LIBUSB_TRANSFER_FREE_BUFFER | LIBUSB_TRANSFER_FREE_TRANSFER;
	int c = libusb_submit_transfer(transfer_in);
	out_timestamp();
	cout << "Intento recibir datos " << c << endl;
	cout << "Tengo " << pktSize << " como tamaño de paquete" << endl;
}

void USBChecker::receive_cb(struct libusb_transfer* transfer){
	out_timestamp();
	cout << "Estoy en el callback de recepcion" << endl;
	cout << transfer->status << endl;
	switch(transfer->status)
	{
		case LIBUSB_TRANSFER_COMPLETED:
			actual_length = transfer->actual_length;
//			for(int i; i < 512;i++)
//			{
//				if(i%16 == 15)
//					cout << transfer->buffer[i] << endl;
//				else cout << transfer->buffer[i] << '\t';
//			}
			to_check = 1;
			libusb_free_transfer(transfer);
			break;
		case LIBUSB_TRANSFER_ERROR:
			break;
		case LIBUSB_TRANSFER_TIMED_OUT:
			err_timestamp();
			cerr << "El dispositivo no responde." << endl;
			to_exit = 0;
			//timers libres. no ocurriría
			break;
		case LIBUSB_TRANSFER_CANCELLED:
			//no prgramado para que ocurra
			break;
		case LIBUSB_TRANSFER_STALL:
			//no programado para que ocurra
			break;
		case LIBUSB_TRANSFER_NO_DEVICE:
			//si se desconecta el dispositivo
			err_timestamp();
			cerr << "El dispositivo se desconectó. Se cierra programa." << endl;
			to_exit = 0;
			return;
		case LIBUSB_TRANSFER_OVERFLOW:
			err_timestamp();
			cerr << "Fallo por overflow. Revisar código de generacion de datos. Se cierra programa." << endl;
			to_exit = 0;
			break;
		default:
			break;
	}
}

void out_timestamp(void){
	time_t timer = time(NULL);
	tm *loctimer = localtime(&timer);
	cout << "--------------" << endl;
	cout << loctimer->tm_year << " ";
	cout << loctimer->tm_mon << " ";
	cout << loctimer->tm_mday << " ";
	cout << loctimer->tm_hour << ":";
	cout << loctimer->tm_min << ":";
	cout << loctimer->tm_sec << endl;
	cout << "--------------" << endl;
}

void err_timestamp(void){
	time_t timer = time(NULL);
	tm* loctimer = localtime(&timer);
	cerr << loctimer->tm_year << " ";
	cerr << loctimer->tm_mon << " ";
	cerr << loctimer->tm_mday << " ";
	cerr << loctimer->tm_hour << ":";
	cerr << loctimer->tm_min << ":";
	cerr << loctimer->tm_sec << '\t';
}

int main() {
	time_t pre_timer;
	time_t pos_timer;

	struct timeval tv;
	libusb_context* ctx = NULL;
	libusb_device* dev = NULL;
	libusb_device_handle* handler = NULL;

	static unsigned char buffer_in[MAX_IN_DATA];
	static unsigned char buffer_out[MAX_OUT_DATA];
	vector<err> errs;

	struct sigaction sigIntHandler;

	sigIntHandler.sa_handler = close_myusb_device;
	sigemptyset(&sigIntHandler.sa_mask);
	sigIntHandler.sa_flags = 0;

	sigaction(SIGKILL, &sigIntHandler, NULL);
	sigaction(SIGTERM, &sigIntHandler, NULL);
	sigaction(SIGSTOP, &sigIntHandler, NULL);
	sigaction(SIGQUIT, &sigIntHandler, NULL);

	freopen("errlog","a", stderr);	// redirijo el stderr a un archivo de registro de eventos
									// la función freopen reinicia tbn cerr para que vaya al
									// mismo archivo

	freopen("datalog","a", stdout);

	USBChecker checker(ctx,dev,handler);
	// init the device
	try
	{
		checker.init_myusb_device();
	}
	catch(int e)
	{
		err_timestamp();
		switch(e)
		{
		case NO_DOI:// 			901	//No device of interest
			cerr << "No se encontró dispoitivo. Conecte la placa Cypress" << endl;
			break;
		case NO_PROGR:// 		902	//No programmed Cypress devices
			cerr << "La placa Cypress no se encuentra programada" << endl;
			break;
		case DRIVER_BLOCKED://	903	//Driver couldn't be detach
			cerr << "No se puede alcanzar control de la placa" << endl;
			break;
		case NO_LIBUSB: // 904 // LIBUSB is not working
			cerr << "Nada que hacer. Final del programa"<< endl;
			fclose(stderr); // libero stderr
			fclose(stdout); // libero stdout
			return(904);
		}
		to_exit = 0;
	}
	// init finished

	while(actual_length != 0)
	{
		checker.receiveData(buffer_out);
		tv.tv_sec = 0;
		tv.tv_usec = 10000;
		libusb_handle_events_timeout_completed(ctx,&tv,NULL);
	}
		to_check = 0;

	//ASYNC Transfer
	while(to_exit)
	{
		if(to_send) //send_flag;
		{
			cout << "Entre aquí" << endl;
			checker.dataGenerator(buffer_out);
			checker.sendData(buffer_out);
			to_send = 0;
		}
		if(to_receive)
		{
			checker.receiveData(buffer_in);
			to_receive = 0;
		}
		if(to_check)
		{
			checker.dataChecker(buffer_in, &errs);
			to_check = 0;
		}
		if(to_log)
		{
			out_timestamp();
			cout << "OUT TRANSFER:" << endl;
			for(uint i = 0; i < sizeof(buffer_out); i++)
			{
				if(i%16 != 15)
					cout <<(int) buffer_out[i] << '\t';
				else
					cout << (int) buffer_out[i] << endl;
			}
			cout << "IN TRANSFER:" << endl;
			for(uint i = 0; i < sizeof(buffer_in); i++)
			{
				if(i%16 != 15)
					cout <<(int) buffer_in[i] << '\t';
				else
					cout <<(int) buffer_in[i] << endl;
			}
			if(errs.size() == 0)
				cout << "No hubo errores"<< endl;
			else
			{
				cout << "Errores:" << endl;
				uint j = 0;
				for(uint i = 0; i < errs.size(); i++)
				{
					if(errs.at(i).row != 0)
					{
						cout << "At row: " << errs.at(i).row << endl;
						j++;
					}
					else
						cout << "In block: " << errs.at(i).block << ";cols parity found: " << errs.at(i).check << endl;
					cout << endl;
				}
				cout << "Tasa de error = " << errs.size()/sizeof(buffer_out)*100 << endl;
			}
			to_send = 1;
			cout << "le dije que haga más envío de datos" << endl;
			to_log = 0;
			to_exit = 1;
		}
		tv.tv_sec = 0;
		tv.tv_usec = 10000;
		libusb_handle_events_timeout_completed(ctx,&tv,NULL);
	}

	// deinit begins
	// Release the device by using libusb_release_interface
	checker.closeChecker();
	//libusb_release_interface(handler,0);

	// Close the device you opened before, by using libusb_close
	libusb_close(handler); //cierro el dispoitivo

	// Close the session by using libusb_exit*/
	libusb_exit(ctx); // desconfiguro el contexto y libero la memoria

	fclose(stderr); // libero stderr
	fclose(stdout); // libero stdout

	return 0;
}
