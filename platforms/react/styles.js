
import { StyleSheet } from 'react-native';

export default StyleSheet.create({
    safeArea: {
        flex: 1,
        backgroundColor: '#F8F9FA',
    },
    container: {
        flex: 1,
        padding: 16,
        backgroundColor: '#FFFFFF',
    },
    header: {
        backgroundColor: '#007AFF',
        paddingVertical: 20,
        alignItems: 'center',
        justifyContent: 'center',
        borderBottomLeftRadius: 20,
        borderBottomRightRadius: 20,
    },
    headerText: {
        color: '#FFFFFF',
        fontSize: 28,
        fontWeight: 'bold',
    },
    content: {
        fontSize: 16,
        color: '#333333',
        marginBottom: 10,
    },
    accordionContent: {
        maxHeight: 200,
        padding: 12,
        backgroundColor: '#EAF3FF',
        borderRadius: 12,
        marginVertical: 5,
    },
    copyLabel: {
        fontSize: 14,
        color: '#007AFF',
        textAlign: 'center',
        marginBottom: 10,
        textDecorationLine: 'underline',
    },
    button: {
        backgroundColor: '#007AFF',
        padding: 15,
        borderRadius: 12,
        alignItems: 'center',
        marginTop: 20,
        shadowColor: '#000',
        shadowOpacity: 0.2,
        shadowRadius: 5,
        elevation: 2,
    },
    buttonText: {
        color: '#FFFFFF',
        fontSize: 16,
        fontWeight: 'bold',
    },
});
