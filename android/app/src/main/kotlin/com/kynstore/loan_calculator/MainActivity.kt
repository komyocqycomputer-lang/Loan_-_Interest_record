package com.kynstore.loan_calculator

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.graphics.RectF
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.media.MediaDrm
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.print.pdf.PrintedPdfDocument
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val DRM_CHANNEL = "com.kynstore.loan_calculator/device_drm"
    private val PRINTER_CHANNEL = "com.kynstore.loan_calculator/printer"
    private val REQ_BLUETOOTH_PERMS = 4021
    private val REQ_PICK_VCF_FILE = 4022
    private val REQ_MANAGE_STORAGE = 4023
    private val ACTION_USB_PERMISSION = "com.kynstore.loan_calculator.USB_PERMISSION"

    private var pendingPermResult: MethodChannel.Result? = null
    private var pendingPickVcfResult: MethodChannel.Result? = null
    private var pendingSaveVcfResult: MethodChannel.Result? = null
    private var pendingSaveVcfTempPath: String? = null
    private var pendingSaveVcfFileName: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DRM_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getDrmDeviceId") {
                    result.success(getWidevineDrmId())
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureBluetoothPermissions" -> {
                        ensureBluetoothPermissions(result)
                    }
                    "getPairedBluetoothDevices" -> {
                        getPairedBluetoothDevices(result)
                    }
                    "printBluetoothEscPos" -> {
                        val address = call.argument<String>("address") ?: ""
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Print data is empty", null)
                        } else {
                            printBluetoothEscPos(address, bytes, result)
                        }
                    }
                    "printNetworkEscPos" -> {
                        val host = call.argument<String>("host") ?: ""
                        val port = call.argument<Int>("port") ?: 9100
                        val bytes = call.argument<ByteArray>("bytes")
                        if (host.isBlank() || bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGS", "IP Address သို့မဟုတ် Print data မပြည့်စုံပါ", null)
                        } else {
                            printNetworkEscPos(host.trim(), port, bytes, result)
                        }
                    }
                    "printUsbEscPos" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Print data is empty", null)
                        } else {
                            printUsbEscPos(bytes, result)
                        }
                    }
                    "printSystemBitmap" -> {
                        val pngBytes = call.argument<ByteArray>("pngBytes")
                        val jobName = call.argument<String>("jobName") ?: "Loan_Receipt"
                        if (pngBytes == null || pngBytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Receipt image is empty", null)
                        } else {
                            printSystemBitmap(pngBytes, jobName, result)
                        }
                    }
                    "openRawBt" -> {
                        val base64Png = call.argument<String>("base64Png") ?: ""
                        openRawBt(base64Png, result)
                    }
                    "saveReceiptToGallery" -> {
                        val pngBytes = call.argument<ByteArray>("pngBytes")
                        val fileName = call.argument<String>("fileName")
                            ?: "Receipt_${System.currentTimeMillis()}.png"
                        if (pngBytes == null || pngBytes.isEmpty()) {
                            result.error("INVALID_ARGS", "Receipt image is empty", null)
                        } else {
                            saveReceiptToGallery(pngBytes, fileName, result)
                        }
                    }
                    "saveVcfToInternalStorage" -> {
                        val tempFilePath = call.argument<String>("tempFilePath") ?: ""
                        val fileName = call.argument<String>("fileName") ?: "loan_records_backup.vcf"
                        if (tempFilePath.isBlank()) {
                            result.error("INVALID_ARGS", "VCF temp file path is empty", null)
                        } else {
                            saveVcfToInternalStorage(tempFilePath, fileName, result)
                        }
                    }
                    "pickVcfFile" -> {
                        pickVcfFile(result)
                    }
                    "openExternalUri" -> {
                        val uriStr = call.argument<String>("uri") ?: ""
                        val fallbackUriStr = call.argument<String>("fallbackUri") ?: ""
                        openExternalUri(uriStr, fallbackUriStr, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openExternalUri(
        uriStr: String,
        fallbackUriStr: String,
        result: MethodChannel.Result
    ) {
        if (uriStr.isBlank()) {
            result.success(false)
            return
        }
        try {
            val uri = Uri.parse(uriStr)
            val action = if (uriStr.startsWith("tel:", ignoreCase = true)) {
                Intent.ACTION_DIAL
            } else {
                Intent.ACTION_VIEW
            }
            val intent = Intent(action, uri).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            if (fallbackUriStr.isNotBlank()) {
                try {
                    val fbUri = Uri.parse(fallbackUriStr)
                    val fbAction = if (fallbackUriStr.startsWith("tel:", ignoreCase = true)) {
                        Intent.ACTION_DIAL
                    } else {
                        Intent.ACTION_VIEW
                    }
                    val fbIntent = Intent(fbAction, fbUri).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(fbIntent)
                    result.success(true)
                    return
                } catch (_: Exception) {
                }
            }
            result.success(false)
        }
    }

    private fun hasBluetoothPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun ensureBluetoothPermissions(result: MethodChannel.Result) {
        if (hasBluetoothPermissions()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            pendingPermResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_SCAN
                ),
                REQ_BLUETOOTH_PERMS
            )
        } else {
            result.success(true)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_BLUETOOTH_PERMS) {
            val res = pendingPermResult
            pendingPermResult = null
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            res?.success(granted)
        }
    }

    private fun isLikelyPrinter(device: BluetoothDevice): Boolean {
        return try {
            val name = (device.name ?: "").uppercase()
            val printerKeywords = listOf(
                "POS", "MTP", "MPT", "PT-", "RPP", "XP-", "XPRINTER", "PRINTER",
                "THERMAL", "58", "80", "BT-", "SPP", "GOOJPRT", "RONGTA", "ZJIANG", "SUNMI"
            )
            val nameMatch = printerKeywords.any { name.contains(it) }
            val btClass = device.bluetoothClass
            val majorMatch = btClass?.majorDeviceClass == BluetoothClass.Device.Major.IMAGING ||
                btClass?.majorDeviceClass == BluetoothClass.Device.Major.UNCATEGORIZED
            nameMatch || majorMatch
        } catch (_: SecurityException) {
            false
        }
    }

    @Suppress("MissingPermission")
    private fun getPairedBluetoothDevices(result: MethodChannel.Result) {
        if (!hasBluetoothPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth ခွင့်ပြုချက် လိုအပ်ပါသည်", null)
            return
        }
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("NO_BLUETOOTH", "ဤစက်တွင် Bluetooth မပါရှိပါ", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "ကျေးဇူးပြု၍ ဖုန်း၏ Bluetooth ကို အရင်ဖွင့်ပေးပါ", null)
            return
        }

        val bonded = adapter.bondedDevices?.toList() ?: emptyList()
        val sorted = bonded.sortedByDescending { isLikelyPrinter(it) }
        val list = sorted.map { dev ->
            mapOf(
                "name" to (dev.name ?: "Bluetooth Printer"),
                "address" to dev.address,
                "isPrinter" to isLikelyPrinter(dev)
            )
        }
        result.success(list)
    }

    @Suppress("MissingPermission")
    private fun printBluetoothEscPos(
        requestedAddress: String,
        bytes: ByteArray,
        result: MethodChannel.Result
    ) {
        if (!hasBluetoothPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth ခွင့်ပြုချက် လိုအပ်ပါသည်", null)
            return
        }
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "ကျေးဇူးပြု၍ Bluetooth ဖွင့်ထားပေးပါ", null)
            return
        }

        Thread {
            var socket: BluetoothSocket? = null
            try {
                adapter.cancelDiscovery()

                val bonded = adapter.bondedDevices?.toList() ?: emptyList()
                val targetDevice: BluetoothDevice? = if (requestedAddress.isNotBlank()) {
                    bonded.firstOrNull { it.address.equals(requestedAddress, ignoreCase = true) }
                        ?: adapter.getRemoteDevice(requestedAddress)
                } else {
                    bonded.sortedByDescending { isLikelyPrinter(it) }.firstOrNull()
                }

                if (targetDevice == null) {
                    runOnUiThread {
                        result.error(
                            "NO_PRINTER",
                            "ချိတ်ဆက်ထားသော Bluetooth Printer မတွေ့ပါ။ ဖုန်း Bluetooth Settings တွင် Printer ကို အရင် Pair လုပ်ပေးပါ။",
                            null
                        )
                    }
                    return@Thread
                }

                val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")

                socket = try {
                    targetDevice.createRfcommSocketToServiceRecord(sppUuid).also { it.connect() }
                } catch (_: Exception) {
                    try {
                        targetDevice.createInsecureRfcommSocketToServiceRecord(sppUuid).also { it.connect() }
                    } catch (_: Exception) {
                        val m = targetDevice.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                        (m.invoke(targetDevice, 1) as BluetoothSocket).also { it.connect() }
                    }
                }

                val out = socket!!.outputStream
                val chunkSize = 512
                var offset = 0
                while (offset < bytes.size) {
                    val end = minOf(offset + chunkSize, bytes.size)
                    out.write(bytes, offset, end - offset)
                    out.flush()
                    offset = end
                    Thread.sleep(20)
                }
                Thread.sleep(900)
                out.close()
                socket.close()

                val devName = targetDevice.name ?: targetDevice.address
                runOnUiThread {
                    result.success(
                        mapOf(
                            "name" to devName,
                            "address" to targetDevice.address
                        )
                    )
                }
            } catch (e: Exception) {
                try {
                    socket?.close()
                } catch (_: Exception) {
                }
                runOnUiThread {
                    result.error(
                        "BT_PRINT_FAILED",
                        "Bluetooth Printer သို့ ပို့၍မရပါ (${e.localizedMessage ?: "Connection failed"})။ ပရင်တာ ပါဝါဖွင့်ထားခြင်း ရှိမရှိ စစ်ဆေးပါ။",
                        null
                    )
                }
            }
        }.start()
    }

    private fun printNetworkEscPos(
        host: String,
        port: Int,
        bytes: ByteArray,
        result: MethodChannel.Result
    ) {
        Thread {
            var socket: Socket? = null
            try {
                socket = Socket()
                socket.connect(InetSocketAddress(host, port), 4500)
                socket.soTimeout = 5000
                val out = socket.getOutputStream()
                out.write(bytes)
                out.flush()
                Thread.sleep(250)
                out.close()
                socket.close()
                runOnUiThread {
                    result.success(true)
                }
            } catch (e: Exception) {
                try {
                    socket?.close()
                } catch (_: Exception) {
                }
                runOnUiThread {
                    result.error(
                        "NET_PRINT_FAILED",
                        "WiFi / Network Printer ($host:$port) သို့ ချိတ်ဆက်၍ မရပါ (${e.localizedMessage ?: "Timeout"})",
                        null
                    )
                }
            }
        }.start()
    }

    private fun findUsbPrinterEndpoint(device: UsbDevice): Pair<UsbInterface, UsbEndpoint>? {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            val isPrinterClass = intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER ||
                intf.interfaceClass == UsbConstants.USB_CLASS_VENDOR_SPEC ||
                device.deviceClass == UsbConstants.USB_CLASS_PRINTER
            for (j in 0 until intf.endpointCount) {
                val ep = intf.getEndpoint(j)
                if (ep.direction == UsbConstants.USB_DIR_OUT &&
                    ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK
                ) {
                    if (isPrinterClass || i == 0) {
                        return Pair(intf, ep)
                    }
                }
            }
        }
        return null
    }

    private fun printUsbEscPos(bytes: ByteArray, result: MethodChannel.Result) {
        val usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
        if (usbManager == null) {
            result.error("NO_USB", "USB စနစ် မရရှိနိုင်ပါ", null)
            return
        }
        val deviceList = usbManager.deviceList
        val targetEntry = deviceList.values.firstOrNull { findUsbPrinterEndpoint(it) != null }
        if (targetEntry == null) {
            result.error(
                "NO_USB_PRINTER",
                "USB Printer ချိတ်ဆက်ထားခြင်း မတွေ့ပါ။ OTG ကြိုးနှင့် Printer ပါဝါကို စစ်ဆေးပါ။",
                null
            )
            return
        }

        if (!usbManager.hasPermission(targetEntry)) {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            val permissionIntent = PendingIntent.getBroadcast(
                this,
                0,
                Intent(ACTION_USB_PERMISSION),
                flags
            )
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (ACTION_USB_PERMISSION == intent.action) {
                        try {
                            unregisterReceiver(this)
                        } catch (_: Exception) {
                        }
                        if (usbManager.hasPermission(targetEntry)) {
                            sendBytesOverUsb(usbManager, targetEntry, bytes, result)
                        } else {
                            result.error("USB_PERM_DENIED", "USB Printer ခွင့်ပြုချက် မရရှိပါ", null)
                        }
                    }
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, IntentFilter(ACTION_USB_PERMISSION), Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(receiver, IntentFilter(ACTION_USB_PERMISSION))
            }
            usbManager.requestPermission(targetEntry, permissionIntent)
            return
        }

        sendBytesOverUsb(usbManager, targetEntry, bytes, result)
    }

    private fun sendBytesOverUsb(
        usbManager: UsbManager,
        device: UsbDevice,
        bytes: ByteArray,
        result: MethodChannel.Result
    ) {
        Thread {
            val pair = findUsbPrinterEndpoint(device)
            if (pair == null) {
                runOnUiThread {
                    result.error("USB_NO_ENDPOINT", "USB Printer Endpoint မတွေ့ပါ", null)
                }
                return@Thread
            }
            val (intf, endpoint) = pair
            val conn = usbManager.openDevice(device)
            if (conn == null) {
                runOnUiThread {
                    result.error("USB_OPEN_FAILED", "USB Printer ဖွင့်၍မရပါ", null)
                }
                return@Thread
            }
            try {
                conn.claimInterface(intf, true)
                val chunkSize = 4096
                var offset = 0
                while (offset < bytes.size) {
                    val len = minOf(chunkSize, bytes.size - offset)
                    val slice = bytes.copyOfRange(offset, offset + len)
                    val transferred = conn.bulkTransfer(endpoint, slice, slice.size, 4000)
                    if (transferred < 0) {
                        throw Exception("USB bulkTransfer failed")
                    }
                    offset += len
                }
                conn.releaseInterface(intf)
                conn.close()
                runOnUiThread {
                    result.success(device.productName ?: "USB Printer")
                }
            } catch (e: Exception) {
                try {
                    conn.releaseInterface(intf)
                    conn.close()
                } catch (_: Exception) {
                }
                runOnUiThread {
                    result.error("USB_PRINT_FAILED", "USB Print မအောင်မြင်ပါ: ${e.localizedMessage}", null)
                }
            }
        }.start()
    }

    private fun printSystemBitmap(
        pngBytes: ByteArray,
        jobName: String,
        result: MethodChannel.Result
    ) {
        try {
            val bitmap = BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size)
            if (bitmap == null) {
                result.error("DECODE_ERROR", "Receipt ပုံ ဖတ်၍မရပါ", null)
                return
            }
            val printManager = getSystemService(Context.PRINT_SERVICE) as? PrintManager
            if (printManager == null) {
                result.error("NO_PRINT_SERVICE", "Android Print Service မရရှိနိုင်ပါ", null)
                return
            }

            val adapter = object : PrintDocumentAdapter() {
                private var printAttributes: PrintAttributes? = null

                override fun onLayout(
                    oldAttributes: PrintAttributes?,
                    newAttributes: PrintAttributes,
                    cancellationSignal: CancellationSignal?,
                    callback: LayoutResultCallback,
                    extras: Bundle?
                ) {
                    if (cancellationSignal?.isCanceled == true) {
                        callback.onLayoutCancelled()
                        return
                    }
                    printAttributes = newAttributes
                    val info = PrintDocumentInfo.Builder("$jobName.pdf")
                        .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                        .setPageCount(1)
                        .build()
                    callback.onLayoutFinished(info, true)
                }

                override fun onWrite(
                    pages: Array<out PageRange>?,
                    destination: ParcelFileDescriptor,
                    cancellationSignal: CancellationSignal?,
                    callback: WriteResultCallback
                ) {
                    val attrs = printAttributes ?: PrintAttributes.Builder()
                        .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                        .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                        .build()
                    val pdfDoc = PrintedPdfDocument(this@MainActivity, attrs)
                    try {
                        val page = pdfDoc.startPage(0)
                        val canvas = page.canvas
                        val pageW = canvas.width.toFloat()
                        val pageH = canvas.height.toFloat()
                        val imgRatio = bitmap.height.toFloat() / bitmap.width.toFloat()

                        var drawW = pageW * 0.92f
                        var drawH = drawW * imgRatio
                        if (drawH > pageH * 0.96f) {
                            drawH = pageH * 0.96f
                            drawW = drawH / imgRatio
                        }
                        val left = (pageW - drawW) / 2f
                        val top = 12f
                        val destRect = RectF(left, top, left + drawW, top + drawH)
                        canvas.drawBitmap(bitmap, null, destRect, null)
                        pdfDoc.finishPage(page)

                        FileOutputStream(destination.fileDescriptor).use { out ->
                            pdfDoc.writeTo(out)
                        }
                        callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
                    } catch (e: Exception) {
                        callback.onWriteFailed(e.localizedMessage)
                    } finally {
                        pdfDoc.close()
                    }
                }
            }

            val attrib = PrintAttributes.Builder()
                .setMediaSize(PrintAttributes.MediaSize.NA_INDEX_3X5)
                .setColorMode(PrintAttributes.COLOR_MODE_MONOCHROME)
                .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                .build()

            printManager.print(jobName, adapter, attrib)
            result.success(true)
        } catch (e: Exception) {
            result.error("SYS_PRINT_ERROR", e.localizedMessage ?: "System Print Error", null)
        }
    }

    private fun openRawBt(base64Png: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse("rawbt:data:image/png;base64,$base64Png")
            val intent = Intent(Intent.ACTION_VIEW, uri)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error(
                "RAWBT_NOT_FOUND",
                "RawBT App မတွေ့ပါ (Bluetooth / WiFi / System Print ခလုတ်များကို တိုက်ရိုက်သုံးနိုင်ပါသည်)",
                null
            )
        }
    }

    private fun saveReceiptToGallery(
        pngBytes: ByteArray,
        fileName: String,
        result: MethodChannel.Result
    ) {
        try {
            val cleanName = if (fileName.endsWith(".png", ignoreCase = true)) {
                fileName
            } else {
                "$fileName.png"
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, cleanName)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_PICTURES + "/LoanReceipts"
                    )
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
                val resolver = applicationContext.contentResolver
                val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                if (uri == null) {
                    result.error("SAVE_FAILED", "Gallery ထဲသို့ သိမ်းဆည်း၍ မရပါ", null)
                    return
                }
                resolver.openOutputStream(uri)?.use { out ->
                    out.write(pngBytes)
                    out.flush()
                }
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                result.success("Pictures/LoanReceipts/$cleanName")
            } else {
                @Suppress("DEPRECATION")
                val picturesDir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_PICTURES
                )
                val folder = File(picturesDir, "LoanReceipts")
                if (!folder.exists()) {
                    folder.mkdirs()
                }
                val outFile = File(folder, cleanName)
                FileOutputStream(outFile).use { out ->
                    out.write(pngBytes)
                    out.flush()
                }
                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(outFile.absolutePath),
                    arrayOf("image/png"),
                    null
                )
                result.success(outFile.absolutePath)
            }
        } catch (e: Exception) {
            result.error(
                "SAVE_ERROR",
                "Gallery ထဲသို့ သိမ်းဆည်းရာတွင် အမှားဖြစ်ပေါ်နေပါသည်: ${e.localizedMessage}",
                null
            )
        }
    }

    private fun saveVcfToInternalStorage(
        tempFilePath: String,
        fileName: String,
        result: MethodChannel.Result
    ) {
        val cleanName = if (fileName.endsWith(".vcf", ignoreCase = true)) {
            fileName
        } else {
            "$fileName.vcf"
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !Environment.isExternalStorageManager()) {
            try {
                pendingSaveVcfResult = result
                pendingSaveVcfTempPath = tempFilePath
                pendingSaveVcfFileName = cleanName
                val intent = Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivityForResult(intent, REQ_MANAGE_STORAGE)
                return
            } catch (_: Exception) {
                pendingSaveVcfResult = null
            }
        }

        writeVcfFileDirectly(tempFilePath, cleanName, result)
    }

    private fun writeVcfFileDirectly(
        tempFilePath: String,
        cleanName: String,
        result: MethodChannel.Result
    ) {
        Thread {
            try {
                val srcFile = File(tempFilePath)
                if (!srcFile.exists()) {
                    runOnUiThread {
                        result.error("NO_SRC", "VCF source file not found", null)
                    }
                    return@Thread
                }

                @Suppress("DEPRECATION")
                val rootDir = Environment.getExternalStorageDirectory()
                val destFile = File(rootDir, cleanName)
                srcFile.copyTo(destFile, overwrite = true)

                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(destFile.absolutePath),
                    arrayOf("text/x-vcard"),
                    null
                )
                runOnUiThread {
                    result.success(destFile.absolutePath)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error(
                        "VCF_SAVE_FAILED",
                        "Phone Internal Storage ထဲသို့ သိမ်းဆည်း၍ မရပါ: ${e.localizedMessage}",
                        null
                    )
                }
            }
        }.start()
    }

    private fun pickVcfFile(result: MethodChannel.Result) {
        try {
            pendingPickVcfResult = result
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val rootUri = Uri.parse("content://com.android.externalstorage.documents/document/primary%3A")
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, rootUri)
                }
            }
            startActivityForResult(intent, REQ_PICK_VCF_FILE)
        } catch (e: Exception) {
            pendingPickVcfResult = null
            result.error("PICK_ERROR", "ဖိုင်ရွေးချယ်သည့်စနစ် ဖွင့်၍မရပါ: ${e.localizedMessage}", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_MANAGE_STORAGE) {
            val res = pendingSaveVcfResult
            val tempPath = pendingSaveVcfTempPath
            val fName = pendingSaveVcfFileName
            pendingSaveVcfResult = null
            pendingSaveVcfTempPath = null
            pendingSaveVcfFileName = null

            if (res != null && tempPath != null && fName != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()) {
                    writeVcfFileDirectly(tempPath, fName, res)
                } else {
                    res.error("PERMISSION_DENIED", "Internal Storage သိမ်းဆည်းခွင့် (All files access) ခွင့်ပြုပေးရန် လိုအပ်ပါသည်", null)
                }
            }
            return
        }

        if (requestCode == REQ_PICK_VCF_FILE) {
            val res = pendingPickVcfResult
            pendingPickVcfResult = null
            if (res == null) return

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                res.success(null)
                return
            }

            val uri = data.data!!
            Thread {
                try {
                    var displayName = "loan_records_backup.vcf"
                    contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (idx >= 0) {
                                displayName = cursor.getString(idx) ?: displayName
                            }
                        }
                    }

                    val localCopy = File(filesDir, "imported_selected.vcf")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(localCopy).use { output ->
                            input.copyTo(output, bufferSize = 65536)
                            output.flush()
                        }
                    }

                    val docId = try {
                        DocumentsContract.getDocumentId(uri)
                    } catch (_: Exception) {
                        ""
                    }
                    val displayPath = if (docId.startsWith("primary:")) {
                        "/storage/emulated/0/${docId.removePrefix("primary:")}"
                    } else {
                        "/storage/emulated/0/$displayName"
                    }

                    runOnUiThread {
                        res.success(
                            mapOf(
                                "displayPath" to displayPath,
                                "localPath" to localCopy.absolutePath
                            )
                        )
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        res.error("READ_VCF_ERROR", "ရွေးချယ်ထားသော .vcf ဖိုင်ကို ဖတ်၍မရပါ: ${e.localizedMessage}", null)
                    }
                }
            }.start()
        }
    }

    private fun getWidevineDrmId(): String {
        val widevineUuid = UUID(-0x121074568629b532L, -0x5c37d8232ae2de13L)
        var mediaDrm: MediaDrm? = null
        try {
            mediaDrm = MediaDrm(widevineUuid)
            val rawBytes = mediaDrm.getPropertyByteArray(MediaDrm.PROPERTY_DEVICE_UNIQUE_ID)
            val digest = MessageDigest.getInstance("SHA-256").digest(rawBytes)
            val hex = digest.take(8).joinToString("") { "%02X".format(it) }
            return hex.chunked(4).joinToString("-")
        } catch (e: Exception) {
            val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "UNKNOWN_DRM_DEVICE"
            val digest = MessageDigest.getInstance("SHA-256").digest(androidId.toByteArray())
            val hex = digest.take(8).joinToString("") { "%02X".format(it) }
            return hex.chunked(4).joinToString("-")
        } finally {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    mediaDrm?.close()
                } else {
                    @Suppress("DEPRECATION")
                    mediaDrm?.release()
                }
            } catch (_: Exception) {
            }
        }
    }
}
